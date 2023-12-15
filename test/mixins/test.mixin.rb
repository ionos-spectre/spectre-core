mixin 'do additional stuff' do |message, subject|
  info 'do some more stuff'
  info "say #{message} #{subject}"
  info "right the answer is #{@some_var}"
end
