require 'open3'

# $stdout.sync = true

thread = Thread.new do
  IO.popen("ruby subtest.rb") do |process|
    process.each do |line|
      puts(line)
    end
  end
end

thread.join
