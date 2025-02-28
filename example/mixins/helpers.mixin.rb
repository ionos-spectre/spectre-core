# This mixin requires an +entity+ parameter to be given
# Otherwise it will raise an error
# It also uses a second parameter +occurance+ which is optional
# Call this mixin with:
#
#   result = also 'consult Tobin's Spirit Guide' do
#     with entity: 'Zuul',
#          occurance: 'refrigerator'
#   end
#
mixin "consult Tobin's Spirit Guide", params: [:entity] do |params|
  # Use the +default_to!+ extension method in order
  # to set default values of optional parameters.
  params.default_to! occurance: 'another dimension'

  info "searching for information about #{params.entity}"
  debug "checking for occurance in #{params.occurance}"

  assert params.entity.not_to be 'present'

  # Like Ruby methods the last statement within a mixin
  # will be returned as a result and can be used in the actual spec.
  'Information about 550 Central Park West'
end
