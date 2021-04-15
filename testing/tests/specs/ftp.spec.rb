describe 'spectre/ftp' do
  context 'sftp' do
    setup do
      check 'sftp connection' do
        sftp 'sftp-server' do
          connect!
        end
      end
    end

    it 'uploads a file to sftp server', tags: [:ftp, :sftp, :upload] do
      info 'uploading dummy file via sftp'

      check 'file upload' do
        sftp 'sftp-server' do
          upload resources['dummy.txt'], to: './dummy.txt'
        end
      end
    end

    it 'downloads a file from sftp server', tags: [:ftp, :sftp, :download] do
      info 'downloading dummy file via sftp'

      check 'file download' do
        sftp 'sftp-server' do
          download './dummy.txt', to: './dummy.txt'
        end
      end

      expect 'the downloaded file to exist' do
        './dummy.txt'.exists?.should_be true
      end
    end
  end

  context 'ftp' do
    setup do
      check 'ftp connection' do
        ftp 'ftp-server' do
          connect!
        end
      end
    end

    it 'uploads a file to ftp server', tags: [:ftp, :upload] do
      info 'uploading dummy file via sftp'

      check 'file upload' do
        ftp 'ftp-server' do
          upload resources['dummy.txt'], to: './dummy.txt'
      end
      end
    end

    it 'downloads a file from ftp server', tags: [:ftp, :download] do
      info 'downloading dummy file via ftp'

      local_filepath = './dummy-ftp.txt'

      ftp 'ftp-server' do
        download './dummy.txt', to: local_filepath
      end

      expect 'the downloaded file to exist' do
        local_filepath.exists?.should_be true
      end

      local_filepath.remove!
    end
  end
end