package EntryFileDrop;
use strict;
use warnings;

my $DropJS = <<'JSEND';

  var $asset_f = jQuery('#assets-field');
  $asset_f.css('z-index', 10);

  function CreateDateString() {
    var now = new Date();
    var month = (now.getMonth() + 1).toString();
    var day = now.getDate().toString();
    if (month.length == 1) month = "0" + month;
    if (day.length == 1) day = "0" + day;
    return now.getFullYear() + "/" + month + "/" + day;
  }
  var dateStr = CreateDateString();

  jQuery('<div></div>')
    .addClass('droppable-cover')
    .css({'z-index': 50, 'position': 'absolute', 'display': 'none', 'background-color': '#DCDDDD'})
    .html('<h2><__trans phrase="Drop the files here!"></h2>')
    .appendTo($asset_f);

  jQuery('<a></a>')
    .text('<__trans phrase="Manage tags">')
    .attr('href', '#')
    .appendTo($asset_f.find('.widget-footer'))
    .click(function () {
      var $id_list = $asset_f.find('#include_asset_ids');
      var asset_ids = $id_list.val();
      var url = '<mt:var name="script_url">?__mode=asset_tags_dialog&blog_id=<mt:var name="blog_id" escape="url">&id='+asset_ids;
      jQuery.fn.mtDialog.open(url);
      return false;
    });

  function insertAsset(id, name, type, thumbnail) {
    var $list = $asset_f.find('#asset-list');
    $list.find('#empty-asset-list').remove();
    if ($list.find('#list-asset-' + id).length) {
      return // this asset already exists
    }
    var $id_list = $asset_f.find('#include_asset_ids');
    var asset_ids = $id_list.val();
    if (asset_ids.length > 0) {
      asset_ids += ',';
    }
    $id_list.val( asset_ids + id );
    var $item = jQuery('<li></li>')
      .attr('id', 'list-asset-'+id)
      .addClass('asset-type-'+type);
    jQuery('<a></a>')
      .attr('href', '<mt:var name="script_url">?__mode=view&_type=asset&blog_id=<mt:var name="blog_id" escape="url">&id='+id)
      .addClass('asset-title')
      .text(name)
      .appendTo($item);
    jQuery('<a></a>')
      .attr('href', 'javascript:removeAssetFromList('+id+')')
      .attr('title', '<__trans phrase="Remove this asset.">')
      .addClass('remove-asset icon-remove icon16 action-icon')
      .text('<__trans phrase="Remove">')
      .appendTo($item);
    if (( type === 'image') && (thumbnail)) {
      $item
        .mouseover( function () { show('list-image-'+id)} )
        .mouseout(  function () { hide('list-image-'+id)} );
      jQuery('<img><img>')
        .attr({ 'id': 'list-image-'+id, 'src': thumbnail })
        .addClass('list-image hidden')
        .appendTo($item);
    }
    $item.appendTo($list);
  }

  jQuery('#assets-field').filedrop({
      fallback_id: 'dummy_not_exists',
      maxfiles: 25,
      maxfilesize: 20,    // max file size in MBs
      url: '<mt:var name="script_url">', // upload handler, handles each file separately
      paramname: 'file',          // POST parameter name used on serverside to reference file
      data: {
          // send POST variables
          __mode: 'upload_asset_xhr',
          blog_id: <mt:var name="blog_id" escape="url">,
          magic_token: '<mt:var name="magic_token">',
          middle_path: dateStr
      },
      docOver: function() {
          // user dragging files anywhere inside the browser document window
          var ppos = $asset_f.offset();
          $asset_f.find('div.droppable-cover')
            .css('top', ppos.top).css('left', ppos.left)
            .height($asset_f.height()).width($asset_f.width())
            .show();
      },
      docLeave: function() {
          // user dragging files out of the browser document window
          $asset_f.find('div.droppable-cover').hide();
      },
      drop: function() {
          // user drops file
          $asset_f.find('div.droppable-cover').hide();
      },
      uploadStarted: function(i, file, len){
          // a file began uploading
          // i = index => 0, 1, 2, 3, 4 etc
          // file is the actual file of the index
          // len = total files user dropped
          jQuery('<div></div>')
            .attr('id', 'asset_xhr_upload_status_' + i)
            .html('Uploading ' + (i+1) + '/' + len + ': ' + file.name)            
            .insertAfter($asset_f.find('#asset-list'));
      },
      error: function(err, file) {
        alert(err);
      },
      uploadFinished: function(i, file, response, time) {
          // response is the data you got back from server in JSON format.
          $asset_f.find('#asset_xhr_upload_status_' + i).remove();
          if (response.error) {
            alert('Could not upload file: '+file.name+' '+response.error);
            return;
          }
          var result = response.result.type;
          if (result === 'success') {
            var res = response.result;
            insertAsset(res.asset_id, file.name, res.asset_type, res.thumbnail);
          }
          else if (result === 'overwrite') {
            // file with this name already exists - ask the user
            var params = response.result.params;
            var $over;

            var overfunc = function (opts, callback) {
              jQuery.post(
                '<mt:var name="script_url">',
                jQuery.extend({
                  __mode: 'upload_asset_xhr',
                  blog_id: <mt:var name="blog_id" escape="url">,
                  magic_token: '<mt:var name="magic_token">',
                  fname: params.fname,
                  temp: params.temp,
                  middle_path: dateStr
                }, opts), callback, 'json');
                $over.remove();
            };

            $over = jQuery('<div></div>')
              .css({'position': 'relative', 'overflow': 'auto'});
            var $b_div = jQuery('<div></div>')
              .css({'float': 'right', 'top': 0})
              .appendTo($over);
            jQuery('<button></button>')
              .text('Yes')
              .addClass('action button')
              .click(function () {
                overfunc( { overwrite_yes: 1 }, function (data) { 
                  var res = data.result;
                  insertAsset(res.asset_id, file.name, res.asset_type, res.thumbnail); 
                });
              })
              .appendTo($b_div);
            jQuery('<button></button>')
              .text('No')
              .addClass('action button')
              .click(function () {
                overfunc( { overwrite_no: 1 }, function (data) { });
              })
              .appendTo($b_div);
            jQuery('<div></div>').text('overwrite '+file.name+'?')
              .appendTo($over);
            $over.appendTo($asset_f.find('#asset_container'));
          }
      }
  });
JSEND

sub template_param {
    my ($cb, $app, $params, $tmpl) = @_;

    my $plugin = $app->component('EntryFileDrop');
    my $blog = $app->blog;
    my $scope = $blog->class . ':' . $blog->id;
    my $cnf = $plugin->get_config_obj($scope);
    my $data = $cnf->data();

    _install_dropzone($cb, $app, $plugin, $data, $params, $tmpl);
    _sort_entry_assets($cb, $app, $plugin, $data, $params, $tmpl);
    _set_assets_css($cb, $app, $plugin, $data, $params, $tmpl);
    _add_class_entry_assets($cb, $app, $plugin, $data, $params, $tmpl);

    return 1;

}

sub _install_dropzone {
    my ($cb, $app, $plugin, $data, $params, $tmpl) = @_;

  my $js_include = '<script type="text/javascript" src="'
    . $app->static_path()
    . 'plugins/EntryFileDrop/jquery.filedrop.js?v='
    . $params->{mt_version_id}
    . '"></script>';
  $params->{js_include} = ($params->{js_include} || '') . $js_include;
    my $d_tmpl = MT::Template->new();
    $d_tmpl->text($plugin->translate_templatized($DropJS));
    my $out = $d_tmpl->build($tmpl->context());
  $params->{jq_js_include} = ($params->{jq_js_include} || '') . $out;
    return;
}

sub _set_assets_css {
    my ($cb, $app, $plugin, $data, $params, $tmpl) = @_;
    my $css = $data->{css_file}
        or return;
    my $js_include = '<link rel="stylesheet" href="' 
        . $css 
        . '?v=' . $params->{mt_version_id} . '" type="text/css" />';
    $params->{js_include} = ($params->{js_include} || '') . $js_include;
    return;
}

sub _sort_entry_assets {
    my ($cb, $app, $plugin, $data, $params, $tmpl) = @_;
    my $assets = $params->{asset_loop};
    return unless $assets and @$assets;

    my $sort_by = $data->{sort_assets_by};
    return unless $sort_by;

    my @asset_ids = map $_->{asset_id}, @$assets;
    my @asset_objs = $app->model('asset')->load({id => \@asset_ids});

    my $sort_order = $data->{sort_assets_order} || 'ascend';
    my $is_meta = 0;
    my $method = 'column';
    if ($sort_by =~ m/^meta\./) {
        $sort_by =~ s/^meta\.//;
        $method = 'meta';
        MT::Meta::Proxy->bulk_load_meta_objects( \@asset_objs );
    }
    my $dirnum = $sort_order eq 'ascend' ? 1 : -1;
    my %asset_objs_map = map { ( $_->id, $_ ) } @asset_objs;
    my @asset_recs = map { { 
        original => $_, 
        sort => $asset_objs_map{ $_->{asset_id} }->$method($sort_by),
        } } @$assets;
    @asset_recs = sort { $dirnum * ( $a->{sort} cmp $b->{sort} ) } @asset_recs;
    @$assets = map $_->{original}, @asset_recs;
    return;
}

sub _add_class_entry_assets {
    my ($cb, $app, $plugin, $data, $params, $tmpl) = @_;
    my $rules_json = $data->{css_actions};
    return unless defined $rules_json and length($rules_json) > 0;
    my $assets = $params->{asset_loop};
    return unless $assets and @$assets;

    require JSON;
    my $rules = JSON::from_json( $rules_json );
    my $sort_by = $data->{sort_assets_by};
    my $method;
    if (not defined $sort_by) {
        $method = undef;
    }
    elsif ( $sort_by =~ m/^meta\./ ) {
        $sort_by =~ s/^meta\.//;
        $method = 'meta';
    }
    else {
        $method = 'column';
    }

    foreach my $rule (@$rules) {
        if ($rule->{type} eq 'else') {
            $rule->{func} = sub { 1 };
        }
        elsif ($rule->{type} eq 'tag') {
            $rule->{func} = sub { $_[0]->has_tag( $_[1]->{val} ) };
        }
        elsif ( not defined $sort_by ) {
            $rule->{func} = sub { 0 };
        }
        elsif ($rule->{type} eq 'eq') {
            $rule->{func} = sub { $_[0]->$method() eq $_[1]->{val} };
        }
        elsif ($rule->{type} eq 'gt') {
            $rule->{func} = sub { $_[0]->$method() gt $_[1]->{val} };
        }
        elsif ($rule->{type} eq 'lt') {
            $rule->{func} = sub { $_[0]->$method() lt $_[1]->{val} };
        }
    }

    my $a_class = $app->model('asset');

    foreach my $asset (@$assets) {
        my $obj = $a_class->load($asset->{asset_id});
        foreach my $rule (@$rules) {
            if ($rule->{func}->( $obj, $rule )) {
                $asset->{asset_type} .= ' ' . $rule->{class};
                last;
            }
        }
    }
    return;
}

sub upload_asset_xhr {
    my $app = shift;

    my $blog = $app->blog
        or return $app->json_error( $app->translate("Invalid request.") );

    my $perms = $app->permissions
        or return $app->json_error( $app->translate("Permission denied.") );

    return $app->json_error( $app->translate("Permission denied.") )
        unless $perms->can_do('upload');

    $app->validate_magic() or return;

    # workaround so they won't return empty lists inside _upload_file
    $app->param('asset_select', ($app->param('asset_select') || ''));
    $app->param('entry_insert', ($app->param('entry_insert') || ''));
    $app->param('edit_field',   ($app->param('edit_field')   || ''));

    require MT::CMS::Asset;
    
    my ( $asset, $bytes ) = MT::CMS::Asset::_upload_file(
        $app,
        require_type => ( $app->param('require_type') || '' ),
        @_,
    );

    return $app->json_error( $app->errstr() )
        unless $asset;
    
    if (not $bytes) {
        # this is an overwrite - we need to ask the user
        # $asset actually contain a template object
        my $tmpl_params = $asset->param();
        my $params = {};
        foreach my $key (qw{ temp fname }) {
            $params->{$key} = $tmpl_params->{$key};
        }
        return $app->json_result(
            {   type   => 'overwrite',
                params => $params,
            }
        );
    }

    my $class = $asset->class();
    my %params;
    if ($class eq 'image') {
        my ($t_url) = $asset->thumbnail_url(Blog => $blog, Width => 100);
        $params{thumbnail} = $t_url;
    }

    return $app->json_result(
        {   type   => 'success',
            asset_id => $asset->id(),
            asset_type => $class,
            %params,
        }
    );

}

sub asset_tags_dialog {
    my $app = shift;
    my $blog_id = $app->param('blog_id');
    my $asset_ids = $app->param('id');
    return $app->errtrans("Invalid request.")
      unless $blog_id;
    return $app->permission_denied()
        if !$app->can_do('access_to_insert_asset_list');
    my @ids = grep /^\d+$/, split ',', $asset_ids;

    my $plugin = MT->component('EntryFileDrop');
    my $suggested_tags = $plugin->get_config_value('suggested_tags', "blog:$blog_id");
    my (@s_tags, @s_rec);
    @s_tags = split ',', $suggested_tags 
        if defined( $suggested_tags ) and length( $suggested_tags );
    foreach my $tag (@s_tags) {
        my $name = $tag;
        my $t = { name => $name };
        $name =~ s/\@/atsign/g;;
        $name =~ s/\$/dollarsign/g;
        $name =~ s/\W//g;
        $t->{id} = $name;
        push @s_rec, $t;
    }

    my $ot_class = $app->model('objecttag');
    my $tag_class = $app->model('tag');
    my $hasher = sub {
        my ( $asset, $row ) = @_;
        my @tags = 
            sort map { $_->name } $tag_class->load(
                undef,
                {   join => $ot_class->join_on('tag_id',
                        { blog_id => $asset->blog_id, 
                          object_id => $asset->id,
                          object_datasource => 'asset', 
                        }, 
                        { unique => 1 } ),
                }
            );
        $row->{tags} = \@tags;
    };

    local $app->{component} = 'EntryFileDrop';
    return $app->listing(
        {   type     => 'asset',
            terms    => { id => \@ids, blog_id => $blog_id },
            args     => undef,
            no_limit => 1,
            code     => $hasher,
            template => 'asset_tags_dialog.tmpl',
            params   => { suggested => \@s_rec },
        }
    );

}

sub blog_config_template {
    my ($plugin, $params, $scope) = @_;
    my $app = MT->instance;
    my $blog_id = $app->param('blog_id');

    my $column_names = $app->model('asset')->column_names;
    if (my $f_class = $app->model('field')) {
        my @fields = $f_class->load({blog_id => [0, $blog_id], obj_type => 'asset'});
        push @$column_names, map "meta.field.".$_->basename, @fields;
    }
    $params->{column_names} = $column_names;

    return $plugin->load_tmpl("suggested_tags.tmpl");
}

1;
