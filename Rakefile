require "pathname"

$LOAD_PATH.unshift Pathname(__dir__).join("lib").to_s

require "minitest/test_task"

Minitest::TestTask.create

desc "Start dev server with auto-restart"
task :dev do
  sh "fd | entr -r rackup -o localhost demo.ru"
end

desc "Type check lib against the RBS comments in it"
task :steep do
  sh "steep", "check"
end

task default: %i[ steep test ]
