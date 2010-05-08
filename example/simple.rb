#encoding: utf-8

$: << File.dirname(__FILE__) + "/../lib/"

require 'rbb-push'
PIN = "21C29D7F"
PSID = "454-k5037co1ece3ei34"
PSPWD = "94nLjq1Q"
SERVER = "pushapi.eval.blackberry.com"
PORT = 20381

push = RBB::Push.new( SERVER, PORT, PSID, PSPWD )
begin
  resp = push.push(PIN, "가나다라마바사")
  puts resp
rescue => e 
  puts e.to_s
  puts e.exception.backtrace.join("\n")
end
