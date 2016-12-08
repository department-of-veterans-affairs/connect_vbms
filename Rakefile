require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "rubocop/rake_task"
require "rainbow"
require_relative "./spec/generate_creds"
require_relative "lib/tasks/support/shell_command"

RSpec::Core::RakeTask.new(:spec)

task default: [:spec, :rubocop, :security]

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

desc "Run bundle-audit to check for insecure dependencies"
task :security do
  exit!(1) unless ShellCommand.run("bundle-audit update")
  audit_result = ShellCommand.run("bundle-audit check")

  unless audit_result
    puts Rainbow("Failed. Security vulnerabilities were found.").red
    exit!(1)
  end
  puts Rainbow("Passed. No obvious security vulnerabilities.").green
end

Rake::Task[:build].prerequisites << Rake::Task[:build_java]
