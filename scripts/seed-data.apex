Account acme = new Account(Name = 'Northwind Traders');
insert acme;

Account globex = new Account(Name = 'Globex Corporation');
insert globex;

Contact sarah = new Contact(LastName = 'Chen', AccountId = acme.Id);
Contact marcus = new Contact(LastName = 'Rivera', AccountId = acme.Id);
Contact emily = new Contact(LastName = 'Park', AccountId = globex.Id);
Contact david = new Contact(LastName = 'Nguyen', AccountId = globex.Id);
Contact lisa = new Contact(LastName = 'Brooks', AccountId = acme.Id);
insert new List<Contact>{ sarah, marcus, emily, david, lisa };

List<Case> cases = new List<Case>{
    new Case(
        Subject = 'URGENT - Cannot access system, entire team locked out',
        Description = 'Our entire sales team of 12 people has been unable to log in since 7 AM this morning. We have a major client presentation at 2 PM and this is completely unacceptable. We need this resolved immediately.',
        Priority = 'High',
        Status = 'New',
        Origin = 'Phone',
        ContactId = sarah.Id,
        AccountId = acme.Id
    ),
    new Case(
        Subject = 'Report filters not working as expected',
        Description = 'When I apply a date range filter to the Monthly Sales report, it seems to be including records from outside the selected range. This is affecting our monthly close process.',
        Priority = 'Medium',
        Status = 'Working',
        Origin = 'Email',
        ContactId = marcus.Id,
        AccountId = acme.Id
    ),
    new Case(
        Subject = 'Question about dashboard sharing settings',
        Description = 'Hi team! Love the new updates. I was wondering if there is a way to share my personal dashboard with my manager without making it public to everyone. No rush at all!',
        Priority = 'Low',
        Status = 'New',
        Origin = 'Web',
        ContactId = emily.Id,
        AccountId = globex.Id
    ),
    new Case(
        Subject = 'Data import failed - 3000 records lost',
        Description = 'I ran the data import wizard following all the steps and it said it completed successfully but none of the 3000 contact records appear in the system. I have a deadline tomorrow and this is critical.',
        Priority = 'High',
        Status = 'Escalated',
        Origin = 'Email',
        ContactId = david.Id,
        AccountId = globex.Id
    ),
    new Case(
        Subject = 'Flow automation not triggering on record update',
        Description = 'I built a flow that should send an email when an opportunity stage changes to Closed Won. It works when I test it manually but does not trigger automatically when sales reps update the record.',
        Priority = 'Medium',
        Status = 'New',
        Origin = 'Web',
        ContactId = lisa.Id,
        AccountId = acme.Id
    )
};
insert cases;

System.debug('Seeded ' + cases.size() + ' cases.');
