require "bundler/gem_tasks"
require "tmpdir"

task :default => :spec

task "install:full" do
  pwd = Dir.pwd

  Dir.mktmpdir 'ectoplasm' do |dir|
    `git clone https://cneubaur@bitbucket.org/cneubaur/ectoplasm-ruby.git #{dir}`
    Dir.chdir dir
    `rake install`
    Dir.chdir pwd
  end
end

task :update do
  pwd = Dir.pwd

  Dir.mktmpdir 'spectre' do |dir|
    `git clone https://cneubaur@bitbucket.org/cneubaur/spectre-ruby.git #{dir}`
    Dir.chdir dir
    `rake install`
    Dir.chdir pwd
  end
end
