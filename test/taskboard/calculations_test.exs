defmodule Taskboard.CalculationsTest do
  use ExUnit.Case, async: true

  alias Taskboard.Projects.ProjectTask.Calculations.{ChapterNumber, Overdue, Warning}

  describe "Overdue.calculate/3" do
    test "true for open task with past end_date" do
      records = [%{status: :open, end_date: ~D[2020-01-01]}]
      assert Overdue.calculate(records, [], %{}) == [true]
    end

    test "true for in_progress task with past end_date" do
      records = [%{status: :in_progress, end_date: ~D[2020-01-01]}]
      assert Overdue.calculate(records, [], %{}) == [true]
    end

    test "false for done task regardless of date" do
      records = [%{status: :done, end_date: ~D[2020-01-01]}]
      assert Overdue.calculate(records, [], %{}) == [false]
    end

    test "false for skipped task regardless of date" do
      records = [%{status: :skipped, end_date: ~D[2020-01-01]}]
      assert Overdue.calculate(records, [], %{}) == [false]
    end

    test "false when end_date is nil" do
      records = [%{status: :open, end_date: nil}]
      assert Overdue.calculate(records, [], %{}) == [false]
    end

    test "false when end_date is today" do
      records = [%{status: :open, end_date: Date.utc_today()}]
      assert Overdue.calculate(records, [], %{}) == [false]
    end

    test "false when end_date is in the future" do
      records = [%{status: :open, end_date: ~D[2099-12-31]}]
      assert Overdue.calculate(records, [], %{}) == [false]
    end

    test "handles multiple records correctly" do
      records = [
        %{status: :open, end_date: ~D[2020-01-01]},
        %{status: :open, end_date: ~D[2099-01-01]},
        %{status: :done, end_date: ~D[2020-01-01]}
      ]

      assert Overdue.calculate(records, [], %{}) == [true, false, false]
    end
  end

  describe "Warning.calculate/3" do
    test "true when warning_date reached and task not terminal and not yet overdue" do
      records = [
        %{
          status: :open,
          warning_date: ~D[2020-01-01],
          end_date: ~D[2099-12-31]
        }
      ]

      assert Warning.calculate(records, [], %{}) == [true]
    end

    test "false when warning_date is in the future" do
      records = [
        %{
          status: :open,
          warning_date: ~D[2099-01-01],
          end_date: ~D[2099-12-31]
        }
      ]

      assert Warning.calculate(records, [], %{}) == [false]
    end

    test "false when task is done" do
      records = [
        %{
          status: :done,
          warning_date: ~D[2020-01-01],
          end_date: ~D[2099-12-31]
        }
      ]

      assert Warning.calculate(records, [], %{}) == [false]
    end

    test "false when warning_date is nil" do
      records = [%{status: :open, warning_date: nil, end_date: ~D[2099-12-31]}]
      assert Warning.calculate(records, [], %{}) == [false]
    end

    test "false when end_date has already passed (overdue takes precedence)" do
      records = [
        %{
          status: :open,
          warning_date: ~D[2020-01-01],
          end_date: ~D[2020-02-01]
        }
      ]

      assert Warning.calculate(records, [], %{}) == [false]
    end
  end

  describe "ChapterNumber.calculate/3" do
    test "level 0 task returns its position as string" do
      records = [%{level: 0, position: 3, parent: nil}]
      assert ChapterNumber.calculate(records, [], %{}) == ["3"]
    end

    test "level 1 task with parent returns parent.position.position" do
      records = [%{level: 1, position: 2, parent: %{position: 4}}]
      assert ChapterNumber.calculate(records, [], %{}) == ["4.2"]
    end

    test "level 1 task without parent loaded returns ?.position" do
      records = [%{level: 1, position: 1, parent: nil}]
      assert ChapterNumber.calculate(records, [], %{}) == ["?.1"]
    end

    test "handles multiple records" do
      records = [
        %{level: 0, position: 1, parent: nil},
        %{level: 1, position: 1, parent: %{position: 1}},
        %{level: 1, position: 2, parent: %{position: 1}}
      ]

      assert ChapterNumber.calculate(records, [], %{}) == ["1", "1.1", "1.2"]
    end
  end
end
