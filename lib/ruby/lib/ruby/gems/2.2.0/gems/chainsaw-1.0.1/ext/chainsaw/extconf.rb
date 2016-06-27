require "mkmf"

if ENV['DEBUG'] || ENV['debug']
    puts "enabling debug flags"
    $CFLAGS << ' -g'
    $CFLAGS << ' -O0'
    $CFLAGS << ' -std=c99'
else
    puts "enabling production flags"
    $CFLAGS << ' -flto'
    $CFLAGS << ' -O3'
    $CFLAGS << ' -std=c99'
end

create_makefile("chainsaw")
