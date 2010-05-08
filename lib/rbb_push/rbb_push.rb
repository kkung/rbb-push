module RBB
  require 'base64'
  require 'uuid'
  require 'net/http'
  require 'net/https'
  require 'nokogiri'
  

  class RBBException < Exception 

    attr_accessor :exception, :message
    def initialize(e, message='')
      @exception = e 
      @message = message
    end

  end
  
  class MultipartContainer
    
    attr_accessor :boundary
    attr_reader   :content

    CRLF = "\r\n"

    def initialize(boundary)
      @boundary = boundary
      @parts = []
    end

    def <<(part)
      if part.kind_of?(Part) 
        @parts << part
      else
        @parts << Part.new(part.to_s)
      end
      
      self  #for method chaining
    end

    def to_s
      @content ||= gen_content
    end

    private 
    def gen_content
    
      io = StringIO.new
      io << "--#{boundary}"
      io << CRLF
      @parts.each do |p| 
        io << p.to_s 
        io << "--#{boundary}#{CRLF}" unless @parts.last == p
      end

      io << "--#{boundary}--"
      io << CRLF
      
      io.string 
    end

  end

  class Part

    CONTENT_TYPE = "Content-Type: text/plain; charset=UTF-8"
    CRLF = "\r\n"

    attr_accessor :content_type
    attr_reader   :content

    def initialize(content = '', content_type = CONTENT_TYPE) 
      @content_type = content_type
      set_content(content)
    end

    def content=(content)
      set_content(content)
    end

    def to_s
      @content
    end


    private
    def set_content(content)
      io = StringIO.new
      io << content_type 
      io << CRLF
      io << CRLF
      io << content
      io << CRLF 

      @content = io.string
    end

    
  end

  class Push
  
    attr_accessor :psid, :pspwd, :authentication
    attr_accessor :push_server, :push_port
    attr_reader   :boundary

    def initialize( push_server, push_port, psid, pspwd )    
        
      @psid = psid
      @pspwd = pspwd


      @push_server = push_server
      @push_port = push_port.to_i

    end

    def push(pin, body, options = {})
      
      options = {
        :delivery_method => 'confirmed',
        :delivery_before => Time.now.utc + (60*5),
        :push_id => UUID.generate,
        :timeout => 3
      }.merge(options)

      container = MultipartContainer.new(boundary)
      container << Part.new( gen_pap_wap( 
        pin, 
        options[:push_id], 
        @psid, 
        options[:delivery_before], 
        options[:delivery_method]), "Content-Type: application/xml; charset=UTF-8")

      container << Part.new(body) 
      parse do_post('/mss/PD_pushRequest',  container.to_s, options) 
    end    


    private

    def do_post(url,body, options)
      begin
        
        http = Net::HTTP.new( push_server, 80 )
        http.open_timeout = options[:timeout]
        http.read_timeout = options[:timeout]
        http.start do |http|
          req = Net::HTTP::Post.new(url, gen_header)
          req.body = body
          res = http.request(req)
          case res
          when Net::HTTPSuccess
            return res.body
          else
            res.error!
          end
        end 
      rescue Timeout::Error => e
        throw RBBException.new(e, "push timeout")
      rescue => e
        puts e
        puts e.backtrace.join("\n")
        throw RBBException.new(e, e.message)
      end      
    end 

    def boundary
      @boundary ||= "kkung#{Time.now.to_i}"
    end

    def authentication
      @authentication ||= "Basic #{Base64.encode64(psid+':'+pspwd).strip.gsub(/\r\n/,'')}"  
    end


    def gen_header
      {
        "Content-Type" => "multipart/related; type=\"application/xml\"; boundary=#{boundary}",
        "Authorization" => authentication,
        "X-RIM-PUSH-DEST-PORT" => push_port.to_s,
        "X-WAP-APPLICATION-ID" => "/"
      }
    end

    def gen_pap_wap( pin,push_id, psid, deliver_before, service_quality = 'preferconfirmed')
      builder = Nokogiri::XML::Builder.new(:encoding => 'utf-8') do |xml|
        xml.doc.create_internal_subset( 
          'pap',
          '-//WAPFORUM/DTD PAP 2.0//EN',
          'http://www.openmobilealliance.org/tech/DTD/pap_2.0.dtd' 
        )
        xml.pap do
          xml.send('push-message', { 'push-id' => push_id, 'source-reference' => psid, 'deliver-before-timestamp' => deliver_before.strftime("%Y-%m-%dT%H:%M:%SZ")
}) do
            xml.address( 'address-value' => pin)  
            xml.send('quality-of-service',{'delivery-method' => service_quality })
          end
        end
      end.to_xml
    end

    def parse(result) 
      puts result
      xml = Nokogiri::XML.parse(result)

      raise "Unknown result format" unless xml.root.name == "pap"
      
      push_response = xml.xpath('//push-response').first
      response = xml.xpath('//response-result').first 
      {
        :reply_time => push_response.attributes['reply-time'].value ,
        :push_id => push_response.attributes['push-id'].value,
        :code => response.attributes['code'].value.to_i,
        :desc => response.attributes['desc'].value,
      } 
    end

  end 
end
