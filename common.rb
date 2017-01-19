def files_mtime
  res = {}
  Dir.glob("**/*") do |f|
    res[f] = File.mtime(f).to_i
  end
  res
end