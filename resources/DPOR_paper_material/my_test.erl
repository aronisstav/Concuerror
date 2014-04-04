-module(my_test).

-export([foo_test/0, test/1]).

test(small) ->
    foo_test();
test(large) ->
    foobar_test().

foo_test() ->
    dialyzer:run([{files, ["/home/stavros/git/Concuerror/resources/DPOR_paper_material/foo.erl"]},
                  {from, src_code},
                  {check_plt, false}]).

foobar_test() ->
    dialyzer:run([{files, ["/home/stavros/git/Concuerror/foobar.erl"]}, {from, src_code}]).
