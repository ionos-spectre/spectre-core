describe 'spectre/ftp' do
  context 'sftp' do
    setup do
      observe 'sftp connection' do
        sftp 'sftp_server' do
          connect!
        end
      end

      expect 'the sftp connection to be ok' do
        success?.should_be true
      end
    end

    it 'uploads a file to sftp server', tags: [:ftp, :sftp, :upload, :deps] do
      info 'uploading dummy file via sftp'

      observe 'file upload' do
        sftp 'sftp_server' do
          upload resources['dummy.txt'], to: './dummy.txt'
        end
      end

      expect 'the file upload to succeed' do
        success?.should_be true
      end
    end

    it 'downloads a file from sftp server', tags: [:ftp, :sftp, :download, :deps] do
      info 'downloading dummy file via sftp'

      observe 'file download' do
        sftp 'sftp_server' do
          download './dummy.txt', to: './dummy.txt'
        end
      end

      expect 'the file download to succeed' do
        success?.should_be true
      end

      expect 'the downloaded file to exist' do
        './dummy.txt'.exists?.should_be true
      end
    end

    it 'does not prompt for password', tags: [:ftp, :sftp, :noninteractive, :deps] do
      observe 'trying to connect' do
        sftp env.ftp.sftp_server, username: 'developer', password: 'somewrongpassword' do
          connect!
        end
      end

      expect 'the connection to fail' do
        success?.should_be false
      end
    end
  end

  context 'ftp' do
    setup do
      observe 'ftp connection' do
        ftp 'ftp_server' do
          connect!
        end
      end

      expect 'the ftp connection to be ok' do
        success?.should_be true
      end
    end

    it 'uploads a file to ftp server', tags: [:ftp, :upload, :deps] do
      info 'uploading dummy file via sftp'

      observe 'file upload' do
        ftp 'ftp_server' do
          upload resources['dummy.txt'], to: './dummy.txt'
        end
      end

      expect 'the file upload to succeed' do
        success?.should_be true
      end
    end

    it 'downloads a file from ftp server', tags: [:ftp, :download, :deps] do
      info 'downloading dummy file via ftp'

      local_filepath = './dummy-ftp.txt'

      observe 'file download' do
        ftp 'ftp_server' do
          download './dummy.txt', to: local_filepath
        end
      end

      expect 'the file download to succeed' do
        success?.should_be true
      end

      expect 'the downloaded file to exist' do
        local_filepath.exists?.should_be true
      end

      local_filepath.remove!
    end
  end
end