# --
# OTOBO is a web-based ticketing system for service organisations.
# --
# Copyright (C) 2001-2020 OTRS AG, https://otrs.com/
# Copyright (C) 2019-2020 Rother OSS GmbH, https://otobo.de/
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

use vars (qw($Self));

my $Helper        = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');
my $PackageObject = $Kernel::OM->Get('Kernel::System::Package');
my $ConfigObject  = $Kernel::OM->Get('Kernel::Config');

# Make sure to enable cloud services.
$Helper->ConfigSettingChange(
    Valid => 1,
    Key   => 'CloudServices::Disabled',
    Value => 0,
);

$Helper->ConfigSettingChange(
    Valid => 1,
    Key   => 'Package::AllowNotVerifiedPackages',
    Value => 0,
);

my $RandomID = $Helper->GetRandomID();

# Override Request() from WebUserAgent to always return some test data without making any
#   actual web service calls. This should prevent instability in case cloud services are
#   unavailable at the exact moment of this test run.
my $CustomCode = <<"EOS";
sub Kernel::Config::Files::ZZZZUnitTestAdminPackageManager${RandomID}::Load {} # no-op, avoid warning logs
use Kernel::System::WebUserAgent;
package Kernel::System::WebUserAgent;
use strict;
use warnings;
## nofilter(TidyAll::Plugin::OTOBO::Perl::TestSubs)
{
    no warnings 'redefine';
    sub Request {
        return (
            Status  => '200 OK',
            Content => '{"Success":1,"Results":{"PackageManagement":[{"Operation":"PackageVerify","Data":{"Test":"not_verified","TestPackageIncompatible":"not_verified"},"Success":"1"}]},"ErrorMessage":""}',
        );
    }
}
1;
EOS
$Helper->CustomCodeActivate(
    Code       => $CustomCode,
    Identifier => 'Admin::Package::Upgrade' . $RandomID,
);

my $Location             = $ConfigObject->Get('Home') . '/scripts/test/sample/PackageManager/TestPackage.opm';
my $UpgradeCommandObject = $Kernel::OM->Get('Kernel::System::Console::Command::Admin::Package::Upgrade');

my $ExitCode = $UpgradeCommandObject->Execute($Location);

$Self->Is(
    $ExitCode,
    1,
    "Admin::Package::Upgrade exit code - package is not verified",
);

$ExitCode = $UpgradeCommandObject->Execute($Location);

$Self->Is(
    $ExitCode,
    1,
    "Admin::Package::Upgrade exit code without arguments",
);

1;
