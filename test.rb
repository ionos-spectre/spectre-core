require 'ostruct'

def get_error_info error
  non_spectre_files = error.backtrace.select { |x| !x.include? 'lib/spectre' }

  if non_spectre_files.count > 0
    causing_file = non_spectre_files.first
  else
    causing_file = error.backtrace[0]
  end

  matches = causing_file.match(/(.*\.rb):(\d+)/)

  return '' unless matches

  file, line = matches.captures
  file.slice!(Dir.pwd + '/')

  {
    file: file,
    line: line,
    type: error.class,
    message: error.message,
    backtrace: error.backtrace,
  }
end

class String
  @@colored = false

  def self.colored!
    @@colored = true
  end

  def white; self; end
  def red; colored '31'; end
  def green; colored '32'; end
  def yellow; colored '33'; end
  def blue; colored '34'; end
  def magenta; colored '35'; end
  def cyan; colored '36'; end
  def grey; colored '90'; end

  def bold; colored '1'; end
  def underline; colored '4'; end

  def indent amount
    self.lines.map { |line| (' ' * amount) + line }.join
  end

  private

  def colored ansi_color
    return self unless @@colored

    "\e[#{ansi_color}m#{self}\e[0m"
  end

  alias :error :red
  alias :failed :red
  alias :warn :yellow
  alias :ok :green
  alias :info :blue
  alias :skipped :grey
end

class ConsoleLogger
  def initialize
    @level = 0
    @width = 60
    @indent = 2
  end

  def log message, subject
    if message
      if subject.is_a? DefinitionContext
        message = message.blue
      elsif subject.is_a? TestSpecification
        if ['before', 'after'].include? message
          message = message.magenta
        else
          message = message.cyan
        end
      end

      write(message)
      puts
    end

    if block_given?
      @level += 1

      begin
        yield
      ensure
        @level -= 1
      end
    end
  end

  def progress message
    output_len = write(message)
    result = yield
    print '.' * (@width - output_len)

    status = result[0]

    status_text = "[#{result[0]}]"

    if result[1].nil?
      puts status_text.send(status)
    else
      puts "#{status_text} - #{result[1]}".send(status)
    end
  end

  private

  def indent
    ' ' * (@level * @indent)
  end

  def write message
    output = ''

    if message.empty?
      output = indent
      print output
    else
      message.lines.each do |line|
        output = indent + line
        print output
      end
    end

    output.length
  end
end

class SpectreFailure < Exception
end

class RunContext
  attr_reader :spec, :error, :failure, :skipped, :started, :finished

  def initialize spec, data
    @spec = spec
    @data = data

    @error = nil
    @failure = nil
    @skipped = false

    @started = nil
    @finished = nil
  end

  def info message
    LOGGER.progress(message) { [:info, nil] }
  end

  def fail_with message
    raise SpectreFailure.new(message)
  end

  def expect desc
    LOGGER.progress('expect ' + desc) do
      result = [:ok, nil]

      begin
        yield
      rescue SpectreFailure => e
        @failure = [desc, e.message]
        result = [:failed, nil]
      rescue Interrupt
        @skipped = true
        result = [:skipped, 'canceled by user']
      rescue Exception => e
        @error = e
        result = [:error, e.class.name]
      end

      result
    end
  end

  def run(&)
    begin
      instance_exec(@data, &)
    rescue Interrupt
      LOGGER.progress('') { [:skipped, 'canceled by user'] }
    rescue Exception => e
      @error = e
    end
  end
end

class DefinitionContext
  attr_reader :parent, :desc, :full_desc, :contexts, :specs

  def initialize desc, parent=nil
    @parent = parent
    @desc = desc
    @contexts = []
    @specs = []

    @setups = []
    @teardowns = []

    @befores = []
    @afters = []
  end

  def full_desc
    return @desc unless @parent

    @parent.full_desc + ' ' + @desc
  end

  def context(desc, &)
    context = DefinitionContext.new(desc, self)
    context.instance_eval(&)
    @contexts << context
  end

  def setup &block
    @setups << block
  end

  def teardown &block
    @teardowns << block
  end

  def before &block
    @befores << block
  end

  def after &block
    @afters << block
  end

  def it desc, tags: [], with: nil, &block
    spec = TestSpecification.new(self, desc, tags, with, block, @befores, @afters)
    @specs << spec
  end

  def run tags: []
    specs = @specs.select { |spec| tags.empty? or spec.tags.any? { |tag| tags.include? tag } }

    return [] if specs.empty?

    runs = []

    LOGGER.log(@desc, self) do
      if @setups.any?
        LOGGER.log('setup', self) do
          @setups.each do |block|
            instance_eval(&block)
          end
        end
      end

      runs = specs.map do |spec|
        spec.run
      end

      if @teardowns.any?
        LOGGER.log('teardown', self) do
          @teardowns.each do |block|
            instance_eval(&block)
          end
        end
      end

      @contexts.each do |context|
        runs = runs + context.run(tags: tags)
      end
    end

    runs
  end
end

class TestSpecification
  attr_reader :context, :desc, :tags, :data

  def initialize context, desc, tags, data, block, befores, afters
    @context = context
    @desc = desc
    @tags = tags
    @data = data || [nil]

    @block = block
    @befores = befores
    @afters = afters
  end

  def full_desc
    @context.full_desc + ' ' + @desc
  end

  def run
    @data.map do |data|
      run_context = RunContext.new(self, data)

      LOGGER.log('it ' + @desc, self) do
        begin
          if @befores.any?
            LOGGER.log('before', self) do
              @befores.each do |block|
                run_context.run(&block)
              end
            end
          end

          run_context.run(&@block)
        ensure
          if @afters.any?
            LOGGER.log('after', self) do
              @afters.each do |block|
                run_context.run(&block)
              end
            end
          end
        end
      end

      run_context
    end
  end
end

CONFIG = {
  'spec_patterns' => ['*.spec.rb'],
}

CONTEXTS = []
LOGGER = ConsoleLogger.new

def env
  OpenStruct.new({foo: 'bar'})
end

def describe(name, &)
  main_context = DefinitionContext.new(name)
  main_context.instance_eval(&)
  CONTEXTS << main_context
end

# Load specs
CONFIG['spec_patterns'].each do |pattern|
  Dir.glob(pattern).each do |spec_file|
    require_relative spec_file
  end
end

String.colored!

# Run specs
runs = CONTEXTS.map do |context|
  context.run(tags: [])
end.flatten

succeded = runs.count { |x| x.error.nil? and x.failure.nil? }
errors = runs.count { |x| !x.error.nil? }
failed = runs.count { |x| !x.failure.nil? }
skipped = runs.count { |x| x.skipped }

puts "\n#{succeded} succeded #{failed} failures #{errors} errors #{skipped} skipped\n".send(errors + failed > 0 ? :red : :green)

runs.select { |x| !x.error.nil? or !x.failure.nil? }.each_with_index do |run, index|
  puts "#{index+1}) #{run.spec.full_desc}".red

  if run.error
    str = "but an unexpected error occurred during run\n"
    error_info = get_error_info(run.error)

    str += "  file.....: #{error_info[:file]}\n"
    str += "  type.....: #{error_info[:type]}\n"
    str += "  message..: #{error_info[:message]}\n"

    # str += "  backtrace:\n"
    # error_info[:backtrace].each do |line|
    #   str += "    #{line}\n"
    # end

    puts str.indent(5).red
  end

  if run.failure
    expected, failure = run.failure

    puts "     Expected #{expected} but it failed with:\n     #{failure}\n".red
  end
end
