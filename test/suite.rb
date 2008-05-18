require File.join(File.dirname(__FILE__), "og.rb")

find = File.join(File.dirname(__FILE__), 'og', '**', '*.rb')

Dir.glob(find).each do |file|
  next if File.directory?(file)
  puts "#{file}..."
  require file
end

