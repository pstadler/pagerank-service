require 'uri'
require 'open-uri'

# PageRank library
#
# Ported from http://www.hm2k.com/projects/pagerank
class PageRank
  
  def initialize(uri)
    @uri = uri
    @hash = check_hash(hash_uri)
  end
  
  def get_rank
    begin
      open(request_uri) { |resp| {:rank => ($1.to_i if resp.string =~ /Rank_1:\d:(\d+)/ or nil )} }      
    rescue OpenURI::HTTPError => e
      {:rank => nil, :http_status => e.io.status[0]}
    end
  end
    
  def request_uri
    "http://toolbarqueries.google.com/tbr?client=navclient-auto&ch=#{@hash}&features=Rank&q=info:#{@uri}"
  end

  def str_to_num(uri, check, magic)
    uri.length.times do |i|
      check *= magic
      check += uri[i].ord
    end
    check
  end
  
  def hash_uri
    check1 = str_to_num(@uri, 0x1505, 0x21)
    check2 = str_to_num(@uri, 0, 0x1003f)

    check1 >>= 2
    check1 = ((check1 >> 4) & 0x3ffffc0 ) | (check1 & 0x3f)
    check1 = ((check1 >> 4) & 0x3ffc00 ) | (check1 & 0x3ff)
    check1 = ((check1 >> 4) & 0x3c000 ) | (check1 & 0x3fff)

    t1 = ((((check1 & 0x3c0) << 4) | (check1 & 0x3c)) <<2 ) | (check2 & 0xf0f )
    t2 = ((((check1 & 0xffffc000) << 4) | (check1 & 0x3c00)) << 0xa) | (check2 & 0xf0f0000 )
    t1 | t2
  end
  
  def check_hash(hashnum)
    checkbyte = 0
    flag = 0
    
    hashstr = sprintf('%u', hashnum)
    
    (hashstr.length-1).downto(0) do |i|
      re = hashstr[i].to_i
      if (1 == (flag % 2))      
        re += re
        re = ((re / 10) + (re % 10)).to_i
      end
      checkbyte += re
      flag += 1
    end
    
    checkbyte %= 10
    if (0 != checkbyte)
      checkbyte = 10 - checkbyte
      if (1 == (flag % 2) )
        if (1 == (checkbyte % 2))
          checkbyte += 9
        end
        checkbyte >>= 1
      end
    end
    "7#{checkbyte}#{hashstr}"
  end
  
  private :str_to_num, :hash_uri, :check_hash
  attr_reader :hash, :uri
end

if __FILE__ == $0 and 1 == ARGV.size
  puts PageRank.new(ARGV[0]).get_rank
end
