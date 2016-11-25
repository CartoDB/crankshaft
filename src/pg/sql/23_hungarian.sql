-- https://github.com/esa606/hungarian_algorithm/

create or replace package hungarian_algorithm is

  -- Author  : esa606
  -- Created : 3/16/2015 11:23:12 AM
  -- Purpose : PL/SQL implementation of the Hungarian/Kuhn-Munkres Algorithm
  --           found at http://csclab.murraystate.edu/bob.pilgrim/445/munkres.html
  --           on March 16, 2015.

  /*This software is released under a BSD license, adapted from <http://opensource.org/licenses/bsd-license.php>

  Copyright (c) 2015 esa606. All rights reserved.

  Redistribution and use in source and binary forms, with or without modification,
  are permitted provided that the following conditions are met:

      Redistributions of source code must retain the above copyright notice,
      this list of conditions and the following disclaimer.
      Redistributions in binary form must reproduce the above copyright notice,
      this list of conditions and the following disclaimer in the documentation and/or
      other materials provided with the distribution.
      Neither the name “esa606” nor the names of its contributors may be used to
      endorse or promote products derived from this software without specific prior
      written permission.

  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS “AS IS”
  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
  FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
  SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
  CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
  OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.*/

  --The main function call for this implementation.
  --input table: name of table with the price data.  Prices must be nonnegative integers.
  --row_name_colname: Name of the input_table column holding the price matrix row labels
  --col_name_colname: Name of the input_table column holding the price matrix column labels
  --price_colname: Name of the input_table column holding the price matrix prices
  --logging_mode: 1 for logging, 0 for no logging
  procedure hungarian_main (
    input_table in varchar2,
    row_name_colname in varchar2 default 'row_idx',
    col_name_colname in varchar2 default 'col_idx',
    price_colname in varchar2 default 'price',
    logging_mode in integer default 0
  );

  --A testing function that allows steps of the algorithm to be called according to a string.
  --E.g. hungarian_strstep('123444', ...) would call steps 1, 2, 3, and then 4 three times.
  --May return errors if the specified steps are not algorithmically correct.
  --stepstr: the string specifying the order of the steps
  --Other arguments as above.
  procedure hungarian_strstep (
    stepstr in varchar2,
    input_table in varchar2,
    row_name_colname in varchar2 default 'row_idx',
    col_name_colname in varchar2 default 'col_idx',
    price_colname in varchar2 default 'price',
    logging_mode in integer default 0
  );

end hungarian_algorithm;
/
create or replace package body hungarian_algorithm is

    /*This software is released under a BSD license, adapted from <http://opensource.org/licenses/bsd-license.php>

  Copyright (c) 2015 esa606. All rights reserved.

  Redistribution and use in source and binary forms, with or without modification,
  are permitted provided that the following conditions are met:

      Redistributions of source code must retain the above copyright notice,
      this list of conditions and the following disclaimer.
      Redistributions in binary form must reproduce the above copyright notice,
      this list of conditions and the following disclaimer in the documentation and/or
      other materials provided with the distribution.
      Neither the name “esa606” nor the names of its contributors may be used to
      endorse or promote products derived from this software without specific prior
      written permission.

  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS “AS IS”
  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
  FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
  SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
  CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
  OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.*/

  --Logs calls to the Hungarian Algorithm step-by-step.
  --Typically called by if-statement with variable step_logging_mode.
  --If step_logging_mode = 0, no logging
  --If step_logging_mode = 1, logs with first_call as 0
  --If step_logging_mode = 2, logs with first_call as 1
  procedure hungarian_logging (
    curr_step in integer,
    next_step in integer,
    n in integer,
    first_call in integer default 0
  ) is
    log_cnt integer;
    call_no integer;
  begin
    --Check the initial highest call_no.  Increment it if this
    --is the first call, or re-use if not.
    select count(*)
    into log_cnt
    from hungarian_log
    where rownum = 1;

    if log_cnt = 0 then
      call_no := 1;
    else
      if first_call = 1 then
        select max(call_no) + 1
        into call_no
        from hungarian_log;
      else
       select max(call_no)
        into call_no
        from hungarian_log;
      end if;
    end if;

    insert into hungarian_log
    values (
      call_no,
      current_timestamp,
      curr_step, next_step,
      (select sum(starred) from esa_hungarian_base),
      (select sum(row_covered) from esa_hungarian_base),
      (select sum(col_covered) from esa_hungarian_base),
      (select sum(prime_sequence) from esa_hungarian_base),
      (select sum(z_sequence) from esa_hungarian_base),
      n
    );
    commit;
  end hungarian_logging;


  --A: Transfer initial conditions to base table
  --B: Error-checks initial conditions
  --C: Pads the rows or columns if initial price matrix is not square
  --D: Update elt_idx
  --Returns the matrix size n.
  function hungarian_step1_check_setup (
    input_table in varchar2,
    row_name_colname in varchar2,
    col_name_colname in varchar2,
    price_colname in varchar2,
    step_logging_mode in integer
  ) return integer is
    select_statement varchar2(4000);
    max_price number;
    nonunique_indices_cnt integer;
    num_rows integer;
    num_cols integer;
    first_call integer;
  begin
    --A: This makes all possible combinations of row and column from the input table
    --and then fills in price for the combinations in the input table.
    --If the combo doesn't exist, fills in max_price.
    select_statement := 'select max(' || price_colname || ') from ' || input_table;
    execute immediate select_statement into max_price;

    execute immediate 'truncate table hungarian_base';

    execute immediate
    'insert into hungarian_base
    with t as (
      select
        dense_rank() over (order by ' || row_name_colname || ' asc) as row_idx,
        dense_rank() over (order by ' || col_name_colname || ' asc) as col_idx,
        ' || price_colname  || ' as price
      from ' || input_table || '
    )
    select
      null as elt_idx,
      s.row_idx, s.col_idx,
      case
        when t.price is null then ' || max_price || ' + 1
        else t.price
      end as price,
      0 as starred,
      0 as row_covered,
      0 as col_covered,
      0 as prime_sequence,
      0 as z_sequence
    from (
      select a.row_idx, b. col_idx
      from (select distinct row_idx from t) a
      join (select distinct col_idx from t) b
        on 1 = 1
    ) s

    left join t
      on s.row_idx = t.row_idx
      and s.col_idx = t.col_idx

    order by s.row_idx, s.col_idx';
    commit;

    --B: Error-checking
    select count(*)
    into nonunique_indices_cnt
    from (
      select row_idx, col_idx
      from hungarian_base
      group by row_idx, col_idx
      having count(*) > 1
    );

    if nonunique_indices_cnt > 0 then
      raise_application_error(-20000, 'At least one task/agent combo is not unique.  Check your identifiers.');
    end if;

    --D: Padding out rows or columns with max-price if necessary
    select_statement := 'select count(distinct ' || row_name_colname || ') from ' || input_table;
    execute immediate select_statement into num_rows;

    select_statement := 'select count(distinct ' || col_name_colname || ') from ' || input_table;
    execute immediate select_statement into num_cols;

    if num_rows > num_cols then
      for i in 1..num_rows loop
        for j in (num_cols+1)..num_rows loop
          insert into hungarian_base
          values (null, i, j, max_price + 1, 0, 0, 0, 0, 0);
        end loop;
      end loop;
    elsif num_rows < num_cols then
      for i in (num_rows+1)..num_cols loop
        for j in 1..num_cols loop
          insert into hungarian_base
          values (null, i, j, max_price + 1, 0, 0, 0, 0, 0);
        end loop;
      end loop;
    end if;

    --D: Correct elt_idx.  Since the initial matrix is likely to be incomplete
    --either due to missing links or needing padding, I just wait
    --to do this until that's all filled in.
    update hungarian_base
    set elt_idx = (row_idx - 1)*greatest(num_rows, num_cols) + col_idx;

    if step_logging_mode > 0 then
      if step_logging_mode = 1 then
        first_call := 0;
      else
        first_call := 1;
      end if;
      hungarian_algorithm.hungarian_logging(1, 2, greatest(num_rows, num_cols), first_call);
    end if;

    commit;
    return greatest(num_rows, num_cols);

  end hungarian_step1_check_setup;


  --For each row of the matrix, find the smallest element and
  --subtract it from every element in its row.  Go to Step 3.
  procedure hungarian_step2_reduce (n in integer, step_logging_mode in integer) is
    row_min number;
    first_call integer;
  begin
    for i in 1..n loop

      select min(price)
      into row_min
      from hungarian_base
      where row_idx = i;

      update hungarian_base
      set price = price - row_min
      where row_idx = i;

    end loop;
    commit;

    if step_logging_mode > 0 then
      if step_logging_mode = 1 then
        first_call := 0;
      else
        first_call := 1;
      end if;
      hungarian_algorithm.hungarian_logging(2, 3, null, first_call);
    end if;
  end hungarian_step2_reduce;


  --Find a zero (Z) in the resulting matrix.  If there is no starred zero
  --in its row or column, star Z. Repeat for each element in the matrix.
  --Go to Step 4.
  procedure hungarian_step3_initstar (n in integer, step_logging_mode in integer) is
    ij_price number;
    ij_covered integer;
    first_call integer;
  begin
    for i in 1..n loop
      for j in 1..n loop

        select price
        into ij_price
        from hungarian_base
        where row_idx = i
          and col_idx = j;

        if ij_price = 0 then

          select count(*)
          into ij_covered
          from hungarian_base
          where row_idx = i
            and col_idx = j
            and (row_covered = 1 or col_covered = 1);

          if ij_covered = 0 then

            update hungarian_base
            set starred = 1
            where row_idx = i
              and col_idx = j;

            update hungarian_base
            set row_covered = 1
            where row_idx = i;

            update hungarian_base
            set col_covered = 1
            where col_idx = j;

          end if;
        end if;
      end loop;
    end loop;

    update hungarian_base
    set row_covered = 0,
      col_covered = 0;
    commit;

    if step_logging_mode > 0 then
      if step_logging_mode = 1 then
        first_call := 0;
      else
        first_call := 1;
      end if;
      hungarian_algorithm.hungarian_logging(3, 4, null, first_call);
    end if;
  end hungarian_step3_initstar;


  --Cover each column containing a starred zero.  If n columns
  --are covered, the starred zeros describe a complete set of unique assignments.
  --In this case, Go to Step 8 for finishing touches.
  --Otherwise, Go to Step 5.
  --Returns the step to goto
  function hungarian_step4_coverstarred (n in integer, step_logging_mode in integer) return integer is
    j_starred integer;
    covered_cnt integer;
    next_step integer;
    first_call integer;
  begin
    for j in 1..n loop

      select max(starred)
      into j_starred
      from hungarian_base
      where col_idx = j;

      if j_starred = 1 then

        update hungarian_base
        set col_covered = 1
        where col_idx = j;

      end if;
    end loop;

    select count(distinct col_idx)
    into covered_cnt
    from hungarian_base
    where starred = 1;

    commit;

    if covered_cnt = n then
      next_step := 8; --This is the only place to exit the algorithm, right here
    else
      next_step := 5;
    end if;

    if step_logging_mode > 0 then
      if step_logging_mode = 1 then
        first_call := 0;
      else
        first_call := 1;
      end if;
      hungarian_algorithm.hungarian_logging(4, next_step, null, first_call);
    end if;
    return next_step;
  end hungarian_step4_coverstarred;

  --A: If there are no uncovered zeroes at all, go to Step 7.
  --B: Find a noncovered zero and prime it.
  --C: If there is no starred zero in the row containing this primed zero, go to Step 6.
  --D: Otherwise, cover this row and uncover the column containing the starred zero.
  --E: Return to this step to continue in this manner until there are no uncovered zeros left.
  --Returns the step to goto
  function hungarian_step5_prime (n in integer, step_logging_mode in integer) return integer is
    uncovered_zero_cnt integer;
    min_uncovered_zero integer;
    new_prime_sequence integer;
    most_recently_primed_row integer;
    starred_in_row_cnt integer;
    starred_in_row_col integer;
    next_step integer;
    first_call integer;
  begin
    --Part A
    select count(*)
    into uncovered_zero_cnt
    from hungarian_base
    where row_covered = 0
      and col_covered = 0
      and price = 0;

    if uncovered_zero_cnt = 0 then
      next_step := 7;
    else
      --Part B
      select min(elt_idx)
      into min_uncovered_zero
      from hungarian_base
      where row_covered = 0
        and col_covered = 0
        and price = 0;

      select max(prime_sequence) + 1
      into new_prime_sequence
      from hungarian_base;

      update hungarian_base
      set prime_sequence = new_prime_sequence
      where elt_idx = min_uncovered_zero;

      --Part C
      most_recently_primed_row := ceil(min_uncovered_zero/n);

      select count(*)
      into starred_in_row_cnt
      from hungarian_base
      where row_idx = most_recently_primed_row
        and starred = 1;

      if starred_in_row_cnt = 0 then
        next_step := 6;
      else
        --Part D
        update hungarian_base
        set row_covered = 1
        where row_idx = most_recently_primed_row;

        select col_idx
        into starred_in_row_col
        from hungarian_base
        where row_idx = most_recently_primed_row
          and starred = 1;

        update hungarian_base
        set col_covered = 0
        where col_idx = starred_in_row_col;

        --Part E
        next_step := 5;
      end if;
    end if;

    commit;

    if step_logging_mode > 0 then
      if step_logging_mode = 1 then
        first_call := 0;
      else
        first_call := 1;
      end if;
      hungarian_algorithm.hungarian_logging(5, next_step, null, first_call);
    end if;
    return next_step;
  end hungarian_step5_prime;


  --Construct a series of alternating primed and starred zeros as follows:
  --Let Z0 represent the uncovered primed zero found in Step 5.
  --Let Z1 denote the starred zero in the column of Z0 (if any).
  --Let Z2 denote the primed zero in the row of Z1 (there will always be one).
  --Continue until the series terminates at a primed zero that has no starred
  --zero in its column.
  --The above is accomplished by repeated calls to this step.
  --Then unstar each starred zero of the series, star each primed
  --zero of the series, erase all primes and uncover every line in the matrix.
  --Now return to Step 4.
  --Returns the step to goto
  function hungarian_step6_zsequence (n in integer, step_logging_mode in integer) return integer is
    begin_max_z_sequence integer;
    begin_prime integer;
    begin_prime_col integer;
    starred_zeros_in_prime_col_cnt integer;
    next_step integer;
    first_call integer;
  begin
    --Part A: Add the prime to the sequence.
    --If the sequence is so far empty, add the most recent prime.
    --If the sequence is not empty, add the prime in the row of
    --the most recently added element.
    select max(z_sequence)
    into begin_max_z_sequence
    from hungarian_base;

    if begin_max_z_sequence = 0 then

      select elt_idx
      into begin_prime
      from hungarian_base
      where prime_sequence = (
        select max(prime_sequence)
        from hungarian_base
        );

    else

      select elt_idx
      into begin_prime
      from hungarian_base
      where prime_sequence != 0
        and row_idx = (
          select row_idx
          from hungarian_base
          where z_sequence = begin_max_z_sequence
        );

    end if;

    update hungarian_base
    set z_sequence = begin_max_z_sequence + 1
    where elt_idx = begin_prime;

    --Part B: If there is a starred zero in the newly-added prime's column,
    --add it and repeat.  Otherwise, change markings and return to Step 4.
    begin_prime_col := begin_prime + (1 - ceil(begin_prime/n))*n;

    select count(*)
    into starred_zeros_in_prime_col_cnt
    from hungarian_base
    where price = 0
      and starred = 1
      and col_idx = begin_prime_col;

    if starred_zeros_in_prime_col_cnt > 0 then

      update hungarian_base
      set z_sequence = begin_max_z_sequence + 2
      where col_idx = begin_prime_col
        and starred = 1;

      next_step := 6;

    else

      update hungarian_base
      set starred = 0
      where z_sequence != 0
        and starred = 1;

      update hungarian_base
      set starred = 1
      where z_sequence != 0
        and prime_sequence != 0;

      update hungarian_base
      set row_covered = 0,
        col_covered = 0,
        prime_sequence = 0,
        z_sequence = 0;

      next_step := 4;
    end if;

    commit;

    if step_logging_mode > 0 then
      if step_logging_mode = 1 then
        first_call := 0;
      else
        first_call := 1;
      end if;
      hungarian_algorithm.hungarian_logging(6, next_step, null, first_call);
    end if;

    return next_step;
  end hungarian_step6_zsequence;


  --Add the minimum uncovered price to every element of each covered row,
  --and subtract it from every element of each uncovered column.
  --Return to Step 5 without altering any stars, primes, or covered lines.
  --Returns the step to goto
  function hungarian_step7_addsubtract (step_logging_mode in integer) return integer is
    min_uncovered_price number;
    first_call integer;
  begin
    select min(price)
    into min_uncovered_price
    from hungarian_base
    where row_covered = 0
      and col_covered = 0;

    update hungarian_base
    set price = price + min_uncovered_price*row_covered - min_uncovered_price*(1-col_covered);
    commit;

    if step_logging_mode > 0 then
      if step_logging_mode = 1 then
        first_call := 0;
      else
        first_call := 1;
      end if;
      hungarian_algorithm.hungarian_logging(7, 5, null, first_call);
    end if;

    return 5;

  end hungarian_step7_addsubtract;


  --Creates table hungarian_results with the same row and column names as the
  --input table, showing only the assigned pairs.
  procedure hungarian_step8_results (
    input_table in varchar2,
    row_name_colname in varchar2,
    col_name_colname in varchar2,
    price_colname in varchar2,
    step_logging_mode in integer
  ) is
    table_exists integer;
    row_idx_select varchar2(4000);
    b_row_idx_name varchar2(4000);
    col_idx_select varchar2(4000);
    b_col_idx_name varchar2(4000);
    first_call integer;
  begin
    select count(*)
    into table_exists
    from tab
    where tname = upper('hungarian_results');

    if table_exists = 1 then
      execute immediate 'drop table hungarian_results';
    end if;

    if row_name_colname = 'row_idx' then
      row_idx_select := '';
      b_row_idx_name := 'b_row_idx';
    else
      row_idx_select := 'a.row_idx,';
      b_row_idx_name := 'row_idx';
    end if;

    if col_name_colname = 'col_idx' then
      col_idx_select := '';
      b_col_idx_name := 'b_col_idx';
    else
      col_idx_select := 'a.col_idx,';
      b_col_idx_name := 'col_idx';
    end if;

    execute immediate
    'create table hungarian_results as
    select
      b.' || row_name_colname || ',
      b.' || col_name_colname || ',
      ' || row_idx_select || '
      ' || col_idx_select || '
      b.' || price_colname || '
    from (
      select row_idx, col_idx, elt_idx
      from hungarian_base
      where starred = 1
    ) a

    --Only allows row/column combos that existed in the original
    --to go through.
    join (
      select
        ' || row_name_colname || ',
        ' || col_name_colname || ',
        dense_rank() over (order by ' || row_name_colname || ' asc) as ' || b_row_idx_name || ',
        dense_rank() over (order by ' || col_name_colname || ' asc) as ' || b_col_idx_name || ',
        ' || price_colname  || '
      from ' || input_table || '
    ) b
    on a.row_idx = b.' || b_row_idx_name || '
    and a.col_idx = b.' || b_col_idx_name || '

    order by a.elt_idx';

    commit;

    if step_logging_mode > 0 then
      if step_logging_mode = 1 then
        first_call := 0;
      else
        first_call := 1;
      end if;
      hungarian_algorithm.hungarian_logging(8, null, null, first_call);
    end if;

  end hungarian_step8_results;


  --Steps 4-7 can run in variable order, with repeated calls to each depending on
  --the previous calls.  They output the next step to go to.
  --This function interprets that output and calls the appropriate next step.
  function hungarian_varstep_interpreter (
    stepno in integer,
    n in integer,
    step_logging_mode in integer default 0
  ) return integer is
    next_step integer;
  begin
    if stepno = 4 then
      next_step := hungarian_algorithm.hungarian_step4_coverstarred(n, step_logging_mode);
    elsif stepno = 5 then
      next_step := hungarian_algorithm.hungarian_step5_prime(n, step_logging_mode);
    elsif stepno = 6 then
      next_step := hungarian_algorithm.hungarian_step6_zsequence(n, step_logging_mode);
    elsif stepno = 7 then
      next_step := hungarian_algorithm.hungarian_step7_addsubtract(step_logging_mode);
    end if;

    return next_step;

  end hungarian_varstep_interpreter;


  --The main function call for this implementation.
  --input table: name of table with the price data.  Prices must be nonnegative integers.
  --row_name_colname: Name of the input_table column holding the price matrix row labels
  --col_name_colname: Name of the input_table column holding the price matrix column labels
  --price_colname: Name of the input_table column holding the price matrix prices
  --logging_mode: 1 for logging, 0 for no logging
  procedure hungarian_main (
    input_table in varchar2,
    row_name_colname in varchar2 default 'row_idx',
    col_name_colname in varchar2 default 'col_idx',
    price_colname in varchar2 default 'price',
    logging_mode in integer default 0
  ) is
    step_logging_mode integer;
    n integer;
    next_step integer;
  begin
    if logging_mode = 1 then
      step_logging_mode := 2;
    else
      step_logging_mode := 0;
    end if;

    n := hungarian_algorithm.hungarian_step1_check_setup(
      input_table, row_name_colname, col_name_colname, price_colname, step_logging_mode
    );

    hungarian_algorithm.hungarian_step2_reduce(n, logging_mode);
    hungarian_algorithm.hungarian_step3_initstar(n, logging_mode);

    next_step := 4;

    while next_step < 8 loop
      next_step := hungarian_varstep_interpreter(next_step, n, logging_mode);
    end loop;

    hungarian_algorithm.hungarian_step8_results(
      input_table, row_name_colname, col_name_colname, price_colname, logging_mode
    );

  end hungarian_main;


  --A testing function that allows steps to be called according to a string.
  --E.g. hungarian_strstep('123444') would call steps 1, 2, 3, and then 4 three times.
  --May return errors if the specified steps are not algorithmically correct.
  procedure hungarian_strstep (
    stepstr in varchar2,
    input_table in varchar2,
    row_name_colname in varchar2 default 'row_idx',
    col_name_colname in varchar2 default 'col_idx',
    price_colname in varchar2 default 'price',
    logging_mode in integer default 0
  ) is
    step_logging_mode integer;
    n integer;
    strlen integer;
    num_steps integer;
    eight_last integer;
    stepno integer;
    throwaway integer; --since varstep is a function
  begin
    if substr(stepstr, 1, 3) = '123' then
      if logging_mode = 1 then
        step_logging_mode := 2;
      else
        step_logging_mode := 0;
      end if;
      n := hungarian_algorithm.hungarian_step1_check_setup(
        input_table, row_name_colname, col_name_colname,
        price_colname, step_logging_mode
      );
      step_logging_mode := logging_mode;
      hungarian_algorithm.hungarian_step2_reduce(n, logging_mode);
      hungarian_algorithm.hungarian_step3_initstar(n, logging_mode);
    else
      if logging_mode = 1 then
        step_logging_mode := 2;
      else
        step_logging_mode := 0;
      end if;
    end if;

    strlen := length(stepstr);

    if substr(stepstr, strlen, 1) = '8' then
      num_steps := strlen - 1;
      eight_last := 1;
    else
      num_steps := strlen;
      eight_last := 0;
    end if;

    for i in 4..num_steps loop
      stepno := to_number(substr(stepstr, i, 1));
      if stepno between 4 and 7 then
        throwaway := hungarian_algorithm.hungarian_varstep_interpreter(stepno, n, step_logging_mode);
        step_logging_mode := logging_mode;
      else
        raise_application_error(-20000, 'Intermediate steps must be 4, 5, 6, or 7.');
      end if;
    end loop;

    if eight_last = 1 then
      --In this case Step 8 is also the first step
      if strlen = 1 and logging_mode = 1 then
        step_logging_mode := 2;
      end if;
      hungarian_algorithm.hungarian_step8_results(
        input_table, row_name_colname, col_name_colname, price_colname, step_logging_mode
      );
    end if;

  end hungarian_strstep;

end hungarian_algorithm;
/
