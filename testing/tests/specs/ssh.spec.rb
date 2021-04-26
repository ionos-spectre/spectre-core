describe 'spectre/ssh' do
  it 'can connect with SSH', tags: [:ssh] do
    ssh 'localhost', port: 2222, username: 'developer', password: 'dev' do
      info 'trying to connect'

      expect 'to be able to connect via SSH' do
        can_connect?.should_be true
      end
    end
  end

  it 'can connect with SSH', tags: [:ssh] do
    ssh 'localhost', port: 2222, username: 'developer', password: 'dev' do
      log 'try to list files from user root'

      expect 'a logs directory in root directory' do
        exec 'ls'
        fail_with "no 'logs' directory" if not output.lines.include? 'logs'
      end
    end
  end
end