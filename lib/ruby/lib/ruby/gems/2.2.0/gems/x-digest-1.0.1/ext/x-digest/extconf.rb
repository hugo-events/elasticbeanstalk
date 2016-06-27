require "mkmf"

def use_flto?
    puts"#{`gcc -v`}"
    match_data = /gcc version ([^ ]*) .*/.match(`gcc -v 2>&1`.lines.last)
    if match_data
        gcc_ver = match_data[1]
        return (/[1-4].[0-5].[0-9]+/ !~ gcc_ver.strip)
    end
    true
end

if ENV['DEBUG'] || ENV['debug']
    puts "enabling debug flags"
    $CFLAGS << ' -g'
    $CFLAGS << ' -O0'
else
    puts "enabling production flags"
    $CFLAGS << ' -flto' if use_flto?
    $CFLAGS << ' -O3'
    $CFLAGS << ' -std=c99'
end

create_makefile("xdigest")
