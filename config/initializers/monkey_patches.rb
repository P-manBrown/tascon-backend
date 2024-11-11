Rails.root.glob("lib/monkey_patches/**/*.rb").each do |file|
  require file
end
