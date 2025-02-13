# This mixin requires an +entity+ parameter to be given
# Otherwise it will raise an error
# It also uses a second parameter +occurance+ which is optional
mixin "consult Tobin's Spirit Guide", params: [:entity] do |params|
  info "searching for information about #{params.entity}"
  debug "checking for occurance in #{params.occurance}"
  
  assert params.entity.not_to be 'present'
end
