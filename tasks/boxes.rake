# Boxes maintenance tasks
namespace :boxes do
  task :update => [:repack_main, :repack_testing]

  task :repack_main do
    boxes_dir = File.expand_path("../../example_boxes", __FILE__)
    Dir.chdir(boxes_dir)

    puts "Repacking main box"
    system('tar cvzf ../google.box -C ./gce ./metadata.json')
  end

  task :repack_testing do
    boxes_dir = File.expand_path("../../example_boxes", __FILE__)
    Dir.chdir(boxes_dir)

    puts "Repacking test box"
    system('tar cvzf ../google-test.box -C ./gce-test ./metadata.json ./Vagrantfile')
  end
end
