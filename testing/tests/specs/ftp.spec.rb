describe 'spectre/ftp' do
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

  it 'uploads a file to ftp server', tags: [:ftp, :upload] do
    info 'uploading dummy file via sftp'

    check 'file upload' do
      sftp 'ftp-server' do
        upload resources['dummy.txt'], to: './dummy.txt'
      end
    end
  end

  it 'downloads a file from ftp server', tags: [:ftp, :download] do
    info 'downloading dummy file via sftp'

    check 'file download' do
      sftp 'ftp-server' do
        download './dummy.txt', to: './dummy-ftp.txt'
      end
    end

    expect 'the downloaded file to exist' do
      './dummy-ftp.txt'.exists?.should_be true
    end
  end
end