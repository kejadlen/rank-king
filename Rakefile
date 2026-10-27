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

# Rank King inherits Gloss (https://github.com/kejadlen/gloss) as its
# design system. Gloss ships as plain CSS meant to be copied into a
# consuming project rather than pulled in as a dependency (see its
# install.md), so public/vendor/gloss is a vendored snapshot, and this
# task is how it gets refreshed.
namespace :gloss do
  desc "Refresh the vendored Gloss CSS and JS from a local checkout (GLOSS=path)"
  task :vendor do
    require "fileutils"
    require "pathname"

    checkout = Pathname.new(ENV.fetch("GLOSS") { abort "usage: rake gloss:vendor GLOSS=/path/to/gloss/checkout" })
    commit = `git -C #{checkout} rev-parse HEAD`.strip
    abort "#{checkout} is not a git checkout" unless $?.success?

    out = Pathname.new(__dir__) / "public" / "vendor" / "gloss"
    FileUtils.mkdir_p(out)

    header = <<~CSS
      /* Vendored from kejadlen/gloss @ #{commit}, #{Time.now.utc.strftime("%Y-%m-%d")}.
         Refresh with `rake gloss:vendor GLOSS=/path/to/gloss/checkout`. */

    CSS

    # Mirrors CSS_BUNDLES in Gloss' lib/build.rb.
    bundles = {
      "tokens.css" => %w[assets/css/tokens.css],
      "base.css" => %w[_sass/base/reset.css _sass/base/typography.css],
      "components.css" => %w[
        _sass/components/icon.css
        _sass/components/button.css
        _sass/components/field.css
        _sass/components/badge.css
        _sass/components/card.css
        _sass/components/feedback.css
        _sass/components/tabs.css
      ],
    }

    bundles.each do |name, sources|
      body = sources.map { |source| (checkout / source).read }.join("\n")
      (out / name).write(header + body)
      puts "wrote #{out / name}"
    end

    # The tab keyboard wiring; the theme toggle in it is unused here.
    js = out / "system.js"
    js.write(header + (checkout / "assets/js/system.js").read)
    puts "wrote #{js}"
  end
end
