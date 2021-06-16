@comments
Feature: Comments should be paginated

  Background:
    Given there are 5 comments per page

  Scenario: Multi-chapter work with many comments per chapter
    Given the chaptered work with 6 chapters with 10 comments "Epic WIP"
    When I view the work "Epic WIP"
    Then I should see "Comments (10)"
    When I follow "Comments"
    Then there should be 2 pages of comments

    # All those comments were on the first chapter. Now put some more on
    When I am logged in
      And I view the work "Epic WIP"
      And I view the 3rd chapter
      And I post a comment "The third chapter is especially good."
      And I post a comment "I loved the cliffhanger in chapter 3"
    Then I should see "Comments (2)"

    # Going to the work shows first chapter and only those comments
    When I view the work "Epic WIP"
    Then I should see "Comments (10)"

    # Entire work shows all comments
    When I follow "Entire Work"
    Then I should see "Comments (12)"
    When I follow "Comments (12)"
    Then there should be 3 pages of comments

  Scenario: A work with multiple pages of comments

    Given I have a work "Multipage Comments"
      And the work "Multipage Comments" has 8 normal comments
    When I view the work "Multipage Comments" with comments
    Then there should be 2 pages of comments

  Scenario: A work with multiple pages of spam comments

    Given I have a work "Multipage Comments"
      And the work "Multipage Comments" has 7 spam comments
      And the work "Multipage Comments" has 1 normal comment

    When I am a visitor
      And I view the work "Multipage Comments" with comments
    Then there should be 1 page of comments

    When I am logged in as the author of "Multipage Comments"
      And I view the work "Multipage Comments" with comments
    Then there should be 1 page of comments

    When I am logged in as an admin
      And I view the work "Multipage Comments" with comments
    Then there should be 2 pages of comments

  Scenario: A work with multiple pages of hidden comments

    Given I have a work "Multipage Comments"
      And the work "Multipage Comments" has 7 hidden comments
      And the work "Multipage Comments" has 1 normal comment

    When I am a visitor
      And I view the work "Multipage Comments" with comments
    Then there should be 1 page of comments

    When I am logged in as the author of "Multipage Comments"
      And I view the work "Multipage Comments" with comments
    Then there should be 1 page of comments

    When I am logged in as an admin
      And I view the work "Multipage Comments" with comments
    Then there should be 2 pages of comments

  Scenario: A work with multiple pages of deleted comments

    Given I have a work "Multipage Comments"
      And the work "Multipage Comments" has 7 deleted comments
      And the work "Multipage Comments" has 1 normal comment

    When I am a visitor
      And I view the work "Multipage Comments" with comments
    Then there should be 1 page of comments

    When I am logged in as the author of "Multipage Comments"
      And I view the work "Multipage Comments" with comments
    Then there should be 1 page of comments

    When I am logged in as an admin
      And I view the work "Multipage Comments" with comments
    Then there should be 1 page of comments

  Scenario: A work with multiple pages of unreviewed comments

    Given I have a work "Multipage Comments"
      And the work "Multipage Comments" has 7 unreviewed comments
      And the work "Multipage Comments" has 1 normal comment

    When I am a visitor
      And I view the work "Multipage Comments" with comments
    Then there should be 1 page of comments

    When I am logged in as the author of "Multipage Comments"
      And I view the work "Multipage Comments" with comments
    Then there should be 2 pages of comments

    When I am logged in as an admin
      And I view the work "Multipage Comments" with comments
    Then there should be 2 pages of comments
