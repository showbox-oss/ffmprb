guard :rspec,
  :cmd => 'bin/rspec',
  :run_all => {:cmd => 'bin/rspec --profile'},
  :all_after_pass => true,
  :all_on_start => true,
  :failed_mode => :focus do

  watch(%r{^spec/.+_spec\.rb$})
  watch(%r{^lib/(.+)\.rb$})   { |m| "spec/#{m[1]}_spec.rb" }
  watch('spec/spec_helper.rb')  { 'spec' }
  watch('.rspec')  { 'spec' }
end
