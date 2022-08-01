describe 'spectre/assertion' do
  context 'fails' do
    it 'compares two equal strings and fails', tags: [:assertion, :equal, :fatal] do
      log 'check two string which should not be equal'

      expect 'two strings not to be equal' do
        'foo'.should_not_be 'foo'
      end
    end

    it 'checks string values with grouped boolean operation', tags: [:assertion, :contain, :bool, :fatal] do
      expect '(foo and bar) or (bla and blubb) to be contained' do
        'This text contains bla foo'.should_contain ('foo'.and 'bar').or ('bla'.and 'blubb')
      end
    end

    it 'fails with a specific message', tags: [:assertion, :fail_with, :fatal] do
      expect 'something' do
        fail_with 'a specific message'
      end
    end
  end

  it 'expects code to pass', tags: [:assertion] do
    expect 'two strings to be equal' do
      'foo'.should_be 'foo'
    end

    expect 'two strings not to be equal' do
      'foo'.should_not_be 'bar'
    end
  end

  it 'compares two unequal strings and fails', tags: [:assertion, :equal, :fail] do
    observe do
      'foo'.should_not_be 'foo'
    end

    expect 'the evaluation to fail' do
      success?.should_be false
    end
  end

  it 'compares two equal strings and fails', tags: [:assertion, :equal, :fail] do
    observe do
      'foo'.should_be 'bar'
    end

    expect 'the evaluation to fail' do
      success?.should_be false
    end
  end

  it 'looks up a string which contains another one but it fails', tags: [:assertion, :contain, :fail] do
    observe do
      "this is a pretty long text, that contains bar".should_contain 'foo'
    end

    expect 'the evaluation to fail' do
      success?.should_be false
    end
  end

  it 'observes if an item is in a list and fails', tags: [:assertion, :contain, :array, :fail] do
    observe do
      ['foo', 'bla'].should_contain 'bar'
    end

    expect 'the evaluation to fail' do
      success?.should_be false
    end
  end

  it 'observes a process which succeeds', tags: [:assertion, :observe] do
    observe 'some process' do
      log 'do some stuff'
    end

    expect 'the process to be successful' do
      success?.should_be true
    end
  end

  it 'observes a process which fails', tags: [:assertion, :observe] do
    observe 'some process' do
      raise 'There was a problem'
    end

    expect 'the process to fail' do
      success?.should_be false
    end
  end

  it 'checks string values with boolean operation', tags: [:assertion, :contain, :bool] do
    expect 'foo or bar or (bla and blubb) to be contained' do
      'This text contains bla blubb'.should_contain 'foo'.or 'bar'.or 'bla'.and 'blubb'
    end
  end

  it 'checks string values with boolean operation, but it fails', tags: [:assertion, :contain, :bool, :fail] do
    observe do
      'This text contains bla'.should_contain 'foo'.or 'bar'.or 'bla'.and 'blubb'
    end

    expect 'the evaluation to fail' do
      success?.should_be false
    end
  end

  it 'checks string values with grouped boolean operation', tags: [:assertion, :contain, :bool] do
    expect '(foo and bar) or (bla and blubb) to be contained' do
      'This text contains bar foo'.should_contain ('foo'.and 'bar').or ('bla'.and 'blubb')
    end
  end

  context 'use of custom operators' do
    it 'checks string values with grouped boolean operation', tags: [:assertion, :contain, :bool] do
      expect '(foo and bar) or (bla and blubb) to be contained' do
        'This text contains bar foo'.should_contain ('foo' & 'bar') | ('bla' & 'blubb')
      end
    end

    it 'checks string values with grouped boolean operation, but it fails', tags: [:assertion, :contain, :bool, :fail] do
      observe do
        'This text contains bar blubb'.should_contain ('foo' & 'bar') | ('bla' & 'blubb')
      end

      expect 'the evaluation to fail' do
        success?.should_be false
      end
    end
  end

  it 'checks integer values with grouped boolean operation', tags: [:assertion, :contain, :bool] do
    expect '(1 and 2) or (3 and 4) to be contained' do
      'This text contains 1 2'.should_contain (1.and 2).or (3.and 4)
    end
  end
end
