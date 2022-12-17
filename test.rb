class DslBase
  def method_missing method, *args, **kwargs, &block
    base.method_missing method, *args, **kwargs, &block
  end
end

class Scope
  attr_reader :extensions

  def initialize
    @extensions = {}
  end

  def method_missing method, *args, **kwargs, &block
    puts self.class.name
  end
end

class Context
  def describe desc, &block
    puts desc
    puts eval('self', block.binding)
    instance_eval(&block)
  end

  def log message
    puts message
  end

  def method_missing method, *args, **kwargs, &block
    puts self.class.name
  end
end

class Greeter
  def greet name
    log "Hello #{name}!"
  end
end

scope = Scope.new
scope.extensions[:greet] = Greeter.new

script = <<EOS
describe 'test' do
  greet 'World'
end
EOS

context = Context.new

scope.instance_eval do
  context.instance_eval(script)
end