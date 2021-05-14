describe 'spectre/mysql' do
  setup do
    observe 'mysql developer database' do
      mysql 'developer'
    end

    expect 'mysql to be ok' do
      success?.should_be true
    end

    info 'create todos database'

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
    info 'drop todos database'

    mysql 'localhost' do
      username 'root'
      password 'dev'

      query 'DROP DATABASE IF EXISTS developer'
    end
  end


  before do
    info 'insert dummy data'

    mysql 'developer' do
      database 'developer'
      query "INSERT INTO todos VALUES('Spook arround', false)"
      query "INSERT INTO todos VALUES('Scare some people', false)"
    end
  end


  after do
    info 'delete dummy data'

    mysql 'developer' do
      database 'developer'
      query "DELETE FROM todos"
    end
  end


  it 'connects to a MySQL database', tags: [:mysql, :deps] do
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
end