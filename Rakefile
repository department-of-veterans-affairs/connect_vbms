require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "rubocop/rake_task"
require_relative "./spec/generate_creds"

RSpec::Core::RakeTask.new(:spec)

task default: [:spec, :rubocop]

# Prepare the project for testing
namespace :tests do
  task prepare: [:build, :fixtures]
end

task :build_java do
  sh "make -C src build"
end

task :fixtures do
  generate_test_creds()
end

task :docs do
  sh "make -C docs html"
end

desc "Run RuboCop on the lib directory"
RuboCop::RakeTask.new(:rubocop) do |task|
  task.patterns = ["lib/**/*.rb", "spec/**/*.rb"]
  # Trigger failure for CI
  task.fail_on_error = true
end

Rake::Task[:build].prerequisites << Rake::Task[:build_java]
