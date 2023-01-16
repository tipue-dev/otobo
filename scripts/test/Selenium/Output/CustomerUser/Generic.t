# --
# OTOBO is a web-based ticketing system for service organisations.
# --
# Copyright (C) 2001-2020 OTRS AG, https://otrs.com/
# Copyright (C) 2019-2023 Rother OSS GmbH, https://otobo.de/
# --
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later version.
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.
# --

use strict;
use warnings;
use utf8;

# Set up the test driver $Self when we are running as a standalone script.
use Kernel::System::UnitTest::RegisterDriver;

use vars (qw($Self));

# get selenium object
# OTOBO modules
use Kernel::System::UnitTest::Selenium;
my $Selenium = Kernel::System::UnitTest::Selenium->new( LogExecuteCommandActive => 1 );

$Selenium->RunTest(
    sub {

        # get helper object
        my $Helper = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

        $Helper->ConfigSettingChange(
            Key   => 'CheckEmailAddresses',
            Value => 0,
        );

        # enable CustomerUserGenericTicket sysconfig
        my @CustomerSysConfig = ( '1-GoogleMaps', '2-Google', '2-LinkedIn', '3-XING' );
        my @CustomerUserGenericText;
        for my $SysConfigChange (@CustomerSysConfig) {

            # get default sysconfig
            my $SysConfigName  = 'Frontend::CustomerUser::Item###' . $SysConfigChange;
            my %CustomerConfig = $Kernel::OM->Get('Kernel::System::SysConfig')->SettingGet(
                Name    => $SysConfigName,
                Default => 1,
            );

            # get default link text for each CustomerUserGenericTicket module
            push @CustomerUserGenericText, $CustomerConfig{EffectiveValue}->{Text};

            $Helper->ConfigSettingChange(
                Valid => 1,
                Key   => $SysConfigName,
                Value => $CustomerConfig{EffectiveValue},
            );
        }

        # create test user and login
        my $TestUserLogin = $Helper->TestUserCreate(
            Groups => [ 'admin', 'users' ],
        ) || die "Did not get test user";

        $Selenium->Login(
            Type     => 'Agent',
            User     => $TestUserLogin,
            Password => $TestUserLogin,
        );

        # get test user ID
        my $TestUserID = $Kernel::OM->Get('Kernel::System::User')->UserLookup(
            UserLogin => $TestUserLogin,
        );

        # create test customer user
        my $TestCustomerName = "Customer" . $Helper->GetRandomID();
        my $TestCustomerUser = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerUserAdd(
            Source         => 'CustomerUser',
            UserFirstname  => $TestCustomerName,
            UserLastname   => $TestCustomerName,
            UserCustomerID => 'A124',
            UserLogin      => $TestCustomerName,
            UserEmail      => $TestCustomerName . '@localhost.com',
            UserStreet     => 'Test Street',
            UserCity       => 'Test City',
            UserCountry    => 'Test Country',
            ValidID        => 1,
            UserID         => $TestUserID,
        );

        $Self->True(
            $TestCustomerUser,
            "Created customer user - $TestCustomerUser",
        );

        # get ticket object
        my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

        # create test ticket
        my $TicketID = $TicketObject->TicketCreate(
            Title        => 'Selenium Test Ticket',
            Queue        => 'Raw',
            Lock         => 'unlock',
            Priority     => '3 normal',
            State        => 'open',
            CustomerID   => $TestCustomerUser,
            CustomerUser => $TestCustomerName,
            OwnerID      => $TestUserID,
            UserID       => $TestUserID,
        );
        $Self->True(
            $TicketID,
            "Created ticket - $TicketID",
        );

        # go to zoom view of created test ticket
        my $ScriptAlias = $Kernel::OM->Get('Kernel::Config')->Get('ScriptAlias');
        $Selenium->VerifiedGet("${ScriptAlias}index.pl?Action=AgentTicketZoom;TicketID=$TicketID");

        # Wait until customer info widget has loaded, if necessary.
        $Selenium->WaitFor(
            JavaScript =>
                'return typeof($) === "function" && $(".WidgetIsLoading").length === 0;',
        );

        # check for CustomerUserGeneric link text
        for my $TestText (@CustomerUserGenericText) {
            $Self->True(
                index( $Selenium->get_page_source(), $TestText ) > -1,
                "Link text $TestText - found on screen"
            ) || die;
        }

        # delete created test ticket
        my $Success = $TicketObject->TicketDelete(
            TicketID => $TicketID,
            UserID   => $TestUserID,
        );

        # Ticket deletion could fail if apache still writes to ticket history. Try again in this case.
        if ( !$Success ) {
            sleep 3;
            $Success = $TicketObject->TicketDelete(
                TicketID => $TicketID,
                UserID   => $TestUserID,
            );
        }
        $Self->True(
            $Success,
            "Deleted ticket - $TicketID"
        );

        # delete created test customer user
        $Success = $Kernel::OM->Get('Kernel::System::DB')->Do(
            SQL  => "DELETE FROM customer_user WHERE customer_id = ?",
            Bind => [ \$TestCustomerUser ],
        );
        $Self->True(
            $Success,
            "Deleted CustomerUser - $TestCustomerUser",
        );

        # make sure the cache is correct
        for my $Cache (qw(Ticket CustomerUser)) {
            $Kernel::OM->Get('Kernel::System::Cache')->CleanUp( Type => $Cache );
        }
    }
);

$Self->DoneTesting();
