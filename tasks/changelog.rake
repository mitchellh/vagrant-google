require "fileutils"

# Helper method to insert text after a line that matches the regex
def insert_after_line(file, insert, regex = /^## Next/)
  tempfile = File.open("#{file}.tmp", "w")
  f = File.new(file)
  f.each do |line|
    tempfile << line
    next unless line =~ regex

    tempfile << "\n"
    tempfile << insert
    tempfile << "\n"
  end
  f.close
  tempfile.close

  FileUtils.mv("#{file}.tmp", file)
end

# Extracts all changes that have been made after the latest pushed tag
def changes_since_last_tag
  `git --no-pager log $(git describe --tags --abbrev=0)..HEAD --grep="Merge" --pretty=format:"%t - %s%n%b%n"`
end

# Extracts all github users contributed since last tag
def users_since_last_tag
  `git --no-pager log $(git describe --tags --abbrev=0)..HEAD --grep="Merge" --pretty=format:"%s" | cut -d' ' -f 6 | cut -d/ -f1 | sort | uniq`
end

namespace :changelog do
  task :generate do
    insert_after_line("CHANGELOG.md", changes_since_last_tag, /^## Next/)
    printf("Users contributed since last release:\n")
    contributors = users_since_last_tag.split("\n").map { |name| "@" + name }
    printf("Huge thanks to all our contributors 🎆\n")
    printf("Special thanks to: " + contributors.join(" ") + "\n")
    printf("\nI'll merge this and release the gem once all tests pass.\n")
  end
end
