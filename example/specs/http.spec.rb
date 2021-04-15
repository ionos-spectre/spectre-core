describe 'Webspace Create' do
  it 'add two more domains', tags: [:webspace, :domains] do
    http 'waas_api' do
      method 'POST'
      path 'webspaces'
      json({
        
      })
    end
    
    
  end
end