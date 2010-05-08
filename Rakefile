require 'rake'
require 'spec/rake/spectask'
$: << File.dirname(__FILE__) << "/lib"

desc "Run all specs"
Spec::Rake::SpecTask.new('test') do |t|
  t.spec_files = FileList['spec/**/*.rb']
end
