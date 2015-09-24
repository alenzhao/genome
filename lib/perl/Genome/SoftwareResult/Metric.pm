package Genome::SoftwareResult::Metric;

use strict;
use warnings;

use Genome;
use Hash::Flatten;

class Genome::SoftwareResult::Metric {
    table_name => 'result.metric',
    type_name => 'software result metric',
    id_by => [
        metric_name => { is => 'Text', len => 1000 },
        software_result_id => { is => 'Text', len => 32 },
    ],
    has => [
        metric_value => { is => 'Text', len => 1000 },
        software_result => {
            is => 'Genome::SoftwareResult',
            id_by => 'software_result_id',
            constraint_name => 'SRM_SR_FK',
        },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

sub hash_flattener {
    return Hash::Flatten->new({
        HashDelimiter => "\t",
        OnRefScalar => 'die',
        OnRefRef => 'die',
        OnRefGlob => 'die',
        ArrayDelimiter => "ERROR!",
    });
}

1;
