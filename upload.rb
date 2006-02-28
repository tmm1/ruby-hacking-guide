upload_images = false 

def show_help_and_die
    puts <<EOS
Usage: #{__FILE__} [--help|--upload-images]

--help:            Show this help
--upload-images:   Also upload images (which we do not by default)
EOS
    exit 0
end

if ARGV.size == 1 
    case ARGV.first
        when '--help'
            show_help_and_die

        when '--upload-images'
            upload_images = true
    
        else
            show_help_and_die
    end
end

unless system("scp rhg.css #{Dir.glob('*.html').join(' ')} rubyforge.org:/var/www/gforge-projects/rhg/")
    $STDERR.puts "Error when trying to upload html/css files"
    exit 1
end

if upload_images
    unless system("scp images/*.png rubyforge.org:/var/www/gforge-projects/rhg/images/")
        $STDERR.puts "Error when trying to upload images files"
        exit 1
    end
end
