describe 'spectre/reporter' do
  context 'fails' do
    it 'compares two equal strings and fails', tags: [:reporter, :failure, :fatal] do
      info 'comparing two strings'

      property 'some_id', 123456
      property 'Some other stuff', 'What so ever'

      expect 'two strings not to be equal' do
        'foo'.should_not_be 'foo'
      end
    end

    it 'checks string values with grouped boolean operation', tags: [:reporter, :failure, :fatal] do
      info 'checking is values are contained in the given text'

      expect '(foo and bar) or (bla and blubb) to be contained' do
        'This text contains bla foo'.should_contain ('foo'.and 'bar').or ('bla'.and 'blubb')
      end
    end
  end

  it 'expects code to pass', tags: [:reporter], with: ['bar', 'blubb'] do |data|
    info 'comparing two strings that should be equal'

    expect 'two strings to be equal' do
      'foo'.should_be 'foo'
    end

    info 'comparing two strings that should not be equal'

    property 'foo', 'bar'

    expect 'two strings not to be equal' do
      'foo'.should_not_be data
    end
  end

  it 'expect an error within an expectation', tags: [:reporter, :error, :fatal] do
    info 'do some stuff here'

    expect 'two strings to be equal' do
      raise 'Oops!'
    end
  end

  it 'expect an error within an expectation', tags: [:reporter, :error, :fatal] do
    info 'do some other stuff here'
    raise 'Oops!'
  end
end
