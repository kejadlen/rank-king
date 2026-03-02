$LOAD_PATH.unshift File.expand_path("lib", __dir__)

require "minitest/test_task"

Minitest::TestTask.create

desc "Start dev server with auto-restart"
task :dev do
  sh "fd | entr -r rackup"
end

task default: :test
