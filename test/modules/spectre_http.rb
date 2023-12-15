require 'ostruct'

def http name
  puts "GET #{Spectre::CONFIG['http'][name]['base_url']} "
end

def response
  OpenStruct.new({
    :code => 200,
    :body => 'Hello World',
  })
end
