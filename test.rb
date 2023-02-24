file_content = %[
module Greeter
  @@greeting = 'Hello'

  def say_hello name
    puts @@greeting + ' ' + name
  end

  def self.configure config
    puts config.inspect
  end
end

if @config
  puts @config.inspect

  Greeter.configure(@config)
end

extend Greeter
]

class SpectreExtensions
  def initialize config
    @config = config
  end
end

config = { 'foo' => 'bar' }

run_ctx = SpectreExtensions.new(config)
run_ctx.instance_eval(file_content, __FILE__, 2)

run_ctx.say_hello 'World'

puts run_ctx.instance_variables.inspect
puts run_ctx.singleton_methods
