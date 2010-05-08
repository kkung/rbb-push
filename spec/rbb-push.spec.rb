require 'rbb-push'

module RBB

  describe Part do
    it "should created with correct part" do
      part = Part.new('hello kkung')
      part.to_s.should eql(Part::CONTENT_TYPE+"\r\n\r\nhello kkung\r\n")
    end
  end

  describe MultipartContainer do
    
    it "should created with boundary prop." do
      container = MultipartContainer.new("boundary")
      container.boundary.should eql("boundary")
    end

    it "should process parts combination" do

      boundary = "boundary"
      expected_res = "--#{boundary}\r\nContent-Type: text/plain; charset=UTF-8\r\n\r\npart 1\r\n--#{boundary}\r\nContent-Type: application/xml; charset=UTF-8\r\n\r\n<xml>xml</xml>\r\n--#{boundary}--\r\n"

      container = MultipartContainer.new(boundary)
      container << Part.new("part 1")
      container << Part.new("<xml>xml</xml>", "Content-Type: application/xml; charset=UTF-8")
      container.to_s.should eql(expected_res)
    end

  end

  describe Push do

    it "should create valid Header" do
   
      push_server = "pushapi.eval.blackberry.com"
      push_port = 20381
      pin = "21C29D7F"
      psid = "454-k5037co1ece3ei34"
      pspwd = "94nLjq1Q"

      ex_auth = "Basic " + Base64.encode64(psid+":"+pspwd).strip.gsub(/\r\n/,'')
      push = Push.new(push_server, push_port, psid, pspwd)
      push.should_receive(:boundary).and_return { "boundary" }
      
      header = push.send(:gen_header)
      header["Content-Type"].should eql("multipart/related; type=\"application/xml\"; boundary=boundary")
      header["Authorization"].should eql(ex_auth)
      header["X-RIM-PUSH-DEST-PORT"].should eql(push_port.to_s)
      header["X-WAP-APPLICATION-ID"].should eql "/"


    end
    it "should create valid PAP xml" do
      
      push_server = "pushapi.eval.blackberry.com"
      push_port = 20381
      pin = "21C29D7F"
      psid = "454-k5037co1ece3ei34"
      pspwd = "94nLjq1Q"

      push = Push.new(push_server, push_port, psid, pspwd)
      time = Time.now + (60*5)
      wap = push.send(:gen_pap_wap, pin,"test1234", psid,time )


      xml = Nokogiri::XML.parse(wap)      
      xml.encoding.should eql("utf-8")
      xml.internal_subset.name.should eql("pap")
      xml.internal_subset.external_id.should eql("-//WAPFORUM/DTD PAP 2.0//EN")
      xml.internal_subset.system_id.should eql("http://www.openmobilealliance.org/tech/DTD/pap_2.0.dtd")

      xml.root.name.should eql("pap")
      xml.xpath("//push-message").length.should eql(1)
      xml.xpath('//push-message').first.attributes["push-id"].value.should eql("test1234")
      xml.xpath('//push-message').first.attributes["source-reference"].value.should eql(psid)
      xml.xpath('//push-message').first.attributes["deliver-before-timestamp"].value.should eql(time.strftime("%Y-%m-%dT%H:%M:%SZ"))

      xml.xpath('//address').length.should eql(1)
      xml.xpath('//address').first.attributes['address-value'].value.should eql(pin)
      xml.xpath('//quality-of-service').first.attributes['delivery-method'].value.should eql 'confirmed'
    end

    it "should process response" do
      
      resp_ex = <<-EOS
<?xml version="1.0"?>
<!DOCTYPE pap PUBLIC "-//WAPFORUM//DTD PAP 2.1//EN" "http://www.openmobilealliance.org/tech/DTD/pap_2.1.dtd"><pap><push-response push-id="1c8fa540-3cdf-012d-743a-4061864d7fee" sender-address="http://pushapi.eval.blackberry.com/mss/PD_pushRequest" sender-name="RIM Push-Data Service" reply-time="2010-05-08T14:51:32Z"><response-result code="1001" desc="The request has been accepted for processing."></response-result></push-response></pap>
EOS
       push_server = "pushapi.eval.blackberry.com"
      push_port = 20381
      pin = "21C29D7F"
      psid = "454-k5037co1ece3ei34"
      pspwd = "94nLjq1Q"

      push = Push.new(push_server, push_port, psid, pspwd)

      resp = push.send(:parse, resp_ex)
      resp[:reply_time].should eql("2010-05-08T14:51:32Z")
      resp[:push_id].should eql("1c8fa540-3cdf-012d-743a-4061864d7fee")
      resp[:code].should eql(1001)
      resp[:desc].should eql("The request has been accepted for processing.")

      
      
    end
    
    it "should push" do
       resp_ex = <<-EOS
<?xml version="1.0"?>
<!DOCTYPE pap PUBLIC "-//WAPFORUM//DTD PAP 2.1//EN" "http://www.openmobilealliance.org/tech/DTD/pap_2.1.dtd"><pap><push-response push-id="1c8fa540-3cdf-012d-743a-4061864d7fee" sender-address="http://pushapi.eval.blackberry.com/mss/PD_pushRequest" sender-name="RIM Push-Data Service" reply-time="2010-05-08T14:51:32Z"><response-result code="1001" desc="The request has been accepted for processing."></response-result></push-response></pap>
EOS
      
      push_server = "pushapi.eval.blackberry.com"
      push_port = 20381
      pin = "21C29D7F"
      psid = "454-k5037co1ece3ei34"
      pspwd = "94nLjq1Q"

      p = Push.new(push_server, push_port, psid, pspwd)

      p.should_receive(:do_post).and_return do |*args| 
        resp_ex
      end
      resp = p.push(pin, 'hello push')
      resp[:reply_time].should eql("2010-05-08T14:51:32Z")
      resp[:push_id].should eql("1c8fa540-3cdf-012d-743a-4061864d7fee")
      resp[:code].should eql(1001)
      resp[:desc].should eql("The request has been accepted for processing.")
      

    end
      
  end

end

