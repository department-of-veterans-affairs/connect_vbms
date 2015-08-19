require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

task default: [:build_java, :spec]

task :build_java do
  sh "make -C src build"
end

task :docs do
  sh "make -C docs html"
end

Rake::Task[:build].prerequisites << Rake::Task[:build_java]
