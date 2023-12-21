require 'open3'

# $stdout.sync = true

thread = Thread.new do
  IO.popen("ruby some_ruby_script.rb") do |process|
    process.each do |line|
      puts(line)
    end
  end
end

thread.join
