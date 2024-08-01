Dir[Rails.root.join("lib/monkey_patches/**/*.rb")].each do |file|
  require file
end
