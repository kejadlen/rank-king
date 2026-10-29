# Type checking for lib/. Signatures live in the code as RBS comments
# (`#:` before a method, `# @rbs` for everything else), so the type and
# the implementation are read and changed together. sig/ holds only what
# inline comments cannot express, each file saying why.
target :lib do
  check "lib", inline: true
  # Phlex ships no RBS of its own, so the views are ignored rather than
  # stubbed. inline: true is load-bearing: `ignore` keeps separate lists
  # for plain and inline sources, and a bare `ignore` leaves these checked.
  ignore "lib/rank_king/views", inline: true
  signature "sig"

  library "securerandom", "open3", "net-http", "json", "uri"
end
