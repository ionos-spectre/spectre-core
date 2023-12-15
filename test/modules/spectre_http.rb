require 'ostruct'

def http name
  puts "GET #{CONFIG['http'][name]['base_url']} "
end

def response
  OpenStruct.new({
    :code => 200,
    :body => 'Hello World',
  })
end
