describe 'Spectre' do

  setup do
    log 'do something to setup it all up'
    debug 'this is a debug log text'

    check 'mysql developer database' do
      mysql 'developer'
    end

    mysql 'localhost' do
      username 'root'
      password 'dev'

      query 'DROP DATABASE IF EXISTS developer'
      query 'CREATE DATABASE developer'
      query 'USE developer'
      query 'CREATE TABLE todos(todo_desc VARCHAR(256), done BOOLEAN)'
    end
  end


  teardown do
    info 'do something to bring it all down'

    mysql 'localhost' do
      username 'root'
      password 'dev'

      query 'DROP DATABASE IF EXISTS developer'
    end
  end


  before do
    observe 'insert some data into database' do
      mysql 'developer' do
        database 'developer'
        query "INSERT INTO todos VALUES('Spook arround', false)"
        query "INSERT INTO todos VALUES('Scare some people', false)"
      end
    end
  end


  after do
    observe 'delete all database entries' do
      mysql 'developer' do
        database 'developer'
        query "DELETE FROM todos"
      end
    end
  end


  it 'connects to a MySQL database', tags: [:mysql] do
    mysql 'developer' do
      database 'developer'
      query "SELECT * FROM todos"
    end
    expect 'two entries in database' do
      result.count.should_be 2
    end

    expect 'the first todo not to be completed' do
      result.first.done.should_be false
    end

    mysql do
      query "UPDATE todos SET done = TRUE WHERE todo_desc = 'Spook arround'"
      query "SELECT * FROM todos WHERE todo_desc = 'Spook arround'"
    end

    expect 'the todo to be done' do
      result.first.done.should_be true
    end
  end


  it 'can connect with SSH', tags: [:ssh] do
    ssh 'localhost', port: 2222, username: 'developer', password: 'dev' do
      info 'trying to connect'

      expect 'to be able to connect via SSH' do
        can_connect?.should_be true
      end

      log 'try to list files from user root'

      expect 'a logs directory in root directory' do
        exec 'ls'
        fail_with "no 'logs' directory" if not output.lines.include? 'logs'
      end
    end
  end


  # it 'can connect with FTP', tags: [:ftp] do
  #   expect 'to be able to connect via SSH' do
  #     ftp 'localhost', username: 'developer', password: 'dev' do
  #       can_connect?.should_be true
  #     end
  #   end
  # end


  it 'does a HTTP API request with a preconfigured client', tags: [:http] do

    http 'web_api' do
      method 'GET'
      path 'todos'
      auth 'basic_auth'

      header 'X-Custom', 'Some Value'
      header 'X-Custom2', 'Another Value'

      param 'foo', 'bar'
    end

    expect 'the response code to be 200' do
      response.code.should_be '200'
    end

    expect '2 todos' do
      response.json.count.should_be 2
    end

    log 'get todo details'

    http 'web_api' do
      method 'GET'
      path "todos/#{response.json.first.id}"
      auth 'basic_auth'
    end

    expect 'the response code to be 200' do
      response.code.should_be 200
    end

    expect 'a specific desc text' do
      response.json.desc.should_be 'Spook around'
    end

    http 'web_api' do
      method 'GET'
      path "todos/99999"
      auth 'basic_auth'
    end

    log 'the following expectation fails'

    expect 'the response code to be 200' do
      response.code.should_be 200
    end
  end


  it 'does a HTTP API request with dynamic client', tags: [:http] do
    http 'localhost:4567' do
      method 'GET'
      basic_auth 'developer', 'dev'
      path 'todos/1'
    end

    expect 'the response code to be 200' do
      response.code.should_be 200
    end

    expect 'a specific desc text' do
      response.json.desc.should_be 'Spook around'
    end
  end


  it 'should test some logging', tags: [:log] do
    log 'this is a log message'
    info 'this is a info message'
    debug 'this is a debug message'

    expect 'a log message' do
      log 'this is a log message within an expect block'
    end

    expect 'a positive result' do
    end

    sleep 10

    expect 'another positive result' do
    end
  end


  context 'another context' do
    it 'should test some logging', tags: [:log] do
      log 'this is a log message'
      info 'this is a info message'
      debug 'this is a debug message'

      expect 'log messages' do
        log 'this is a log message within an expect block'
        info 'another info message in the hood'
        debug 'and a debug message within the block'
      end

      expect 'a positive result' do
        sleep 10
      end

      expect 'another positive result' do
      end
    end
  end


  it 'just fails', tags: [:fail] do
    raise 'Opps!'
  end
end