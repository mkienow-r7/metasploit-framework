# msf-payload-generation.ru
# Start using thin:
# thin --rackup msf-payload-generation.ru --address localhost --port 8082 --environment development --tag msf-payload-generation start
#

require 'pathname'
@framework_path = '.'
root = Pathname.new(@framework_path).expand_path
@framework_lib_path = root.join('lib')
$LOAD_PATH << @framework_lib_path unless $LOAD_PATH.include?(@framework_lib_path)

require 'msfenv'

if ENV['MSF_LOCAL_LIB']
  $LOAD_PATH << ENV['MSF_LOCAL_LIB'] unless $LOAD_PATH.include?(ENV['MSF_LOCAL_LIB'])
end

# Note: setup Rails environment before calling require
require 'msf/core/web_services/payload_generation_app'

run Msf::WebServices::PayloadGenerationApp
