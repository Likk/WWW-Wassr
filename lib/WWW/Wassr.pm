package WWW::Wassr;
use strict;
use warnings;
use WWW::Mechanize;
use Web::Scraper;
use LWP::Simple;
use Carp;
our $VERSION = '0.01';

sub new
{
  my $class = shift;
  my %args  = @_;
  $args{'agent'}   ||= "WWW-Wassr/$VERSION (WWW::Wassr $VERSION)";
  $args{'wm'}        = WWW::Mechanize->new( agent=> $args{'agent'} );
  $args{'site_root'} = 'http://wassr.jp';
  return bless {%args}, $class;
}

#===login/out===
sub login
{
  my $self = shift;
  my $data = $self->{'wm'}->get("$self->{site_root}");
  my $forms       = $self->{'wm'}->forms();
  my $CSRFPROTECT = $self->_CSRFPROTECT_parse($data);
  ###warn $CSRFPROTECT;
  $self->CSRFPROTECT($CSRFPROTECT);
  my $post = {
    CSRFPROTECT => $self->CSRFPROTECT(),
    login_id    => $self->{user},
    login_pw    => $self->{passwd},
  };
  $self->{'wm'}->post( "$self->{site_root}/account/login", $post );
}

sub logout
{
  my $self = shift;
  $self->{'wm'}->get("$self->{site_root}/my");
  my $post = { CSRFPROTECT => $self->CSRFPROTECT(), };
  $self->{'wm'}->post( "$self->{site_root}/account/logout", $post );
}

sub CSRFPROTECT
{
  my $self = shift;
  my $CSRFPROTECT = shift || undef;
  $self->{CSRFPROTECT} = $CSRFPROTECT if defined $CSRFPROTECT;
  croak "login failed" if !defined $self->{CSRFPROTECT};
  return $self->{CSRFPROTECT};
}

#===follow===
sub follow
{
  my $self     = shift;
  my $user_id  = shift;
  my $data     = $self->{'wm'}->get("$self->{site_root}/user/$user_id");
  my $user_rid = $self->_get_user_rid($data);
  $self->_follow_toggle($user_rid);
}

sub unfollow
{
  my $self     = shift;
  my $user_id  = shift;
  my $data     = $self->{'wm'}->get("$self->{site_root}/user/$user_id");
  my $user_rid = $self->_get_to_user_rid($data);
  $self->_unfollow_toggle($user_rid);
}

sub _follow_toggle
{
  my $self     = shift;
  my $user_rid = shift;
  my $post     = {
    CSRFPROTECT => $self->CSRFPROTECT(),
    user_rid    => $user_rid,
  };
  $self->{'wm'}->post( "$self->{site_root}/friend/add", $post );
}

sub _unfollow_toggle
{
  my $self     = shift;
  my $user_rid = shift;
  my $post     = {
    CSRFPROTECT => $self->CSRFPROTECT(),
    to_user_rid => $user_rid,
  };
  $self->{'wm'}->post( "$self->{site_root}/my/friend/delete", $post );
}

sub following
{
  my $self        = shift;
  my $frineds_ref = [];
  my $page        = 1;
  while (1){
    my $data =
      $self->{'wm'}
      ->get("$self->{site_root}/my/friend/?type=from&page=$page");
    my $friend_list = $self->_follow_parse($data);
    my $s           = 0;
    eval { $s = scalar(@$friend_list) };
    if ($s)
    {
      push @$frineds_ref, @$friend_list;
    }
    else
    {
      last;
    }
    $page++;
  }
  return $frineds_ref;
}

sub followers
{
  my $self          = shift;
  my $followers_ref = [];
  my $page          = 1;
  while (1)
  {
    my $data =
      $self->{'wm'}
      ->get("$self->{site_root}/my/friend/?type=to&page=$page");
    my $friend_list = $self->_follow_parse($data);
    my $s           = 0;
    eval { $s = scalar(@$friend_list) };
    if ($s)
    {
      push @$followers_ref, @$friend_list;
    }
    else
    {
      last;
    }
    $page++;
  }
  return $followers_ref;
}

#===read===
sub public_timeline
{
  my $self = shift;
  my %args = @_;
  my $page = $args{page} || 1;
  my $data = $self->{'wm'}->get("$self->{site_root}/timeline/public?page=$page");
  return $self->_parse($data);
}

sub friends_timeline
{
  my $self = shift;
  my %args = @_;
  my $page = $args{page} || 1;
  my $data = $self->{'wm'}->get("$self->{site_root}/my/?page=$page");
  return $self->_parse($data);
}


sub user_timeline
{
  my $self         = shift;
  my %args         = @_;
  my $page         = $args{page} || 1;
  my $user_id      = $args{user_id} || $self->{user};
  my $with_friends = $args{with_friends} || 0;
  my $data =
    $self->{'wm'}->get(
    "$self->{site_root}/user/$user_id?page=$page&with_friends=$with_friends"
    );
  return $self->_parse($data);
}

sub sl_timeline
{
  my $self = shift;
  my %args = @_;
  my $page = $args{page} || 1;
  my $data =
    $self->{'wm'}->get("$self->{site_root}/status/sl_list?page=$page");
  return $self->_parse($data);
}

sub fav_timeline
{
  my $self = shift;
  my %args = @_;
  my $page = $args{page} || 1;
  my $data = $self->{'wm'}->get("$self->{site_root}/favorite/?page=$page");
  return $self->_parse($data);
}

sub user_favorites {
  my $self = shift;
  my %args    = @_;
  my $page    = $args{page} || 1;
  my $user_id = $args{user_id} || $self->{user};
  my $data = $self->{'wm'}->get("$self->{site_root}/user/$user_id/favorites?page=$page&ajax_response=0");
  return $self->_parse($data);
}

sub channel_list {
  my $self = shift;
  my %args    = @_;
  my $page    = $args{page} || 1;
  my $data = $self->{'wm'}->get("$self->{site_root}/channel/?page=$page&ajax_response=0");
  return $self->_channel_list_parse($data);
}

sub channel_timeline
{
  my $self       = shift;
  my %args       = @_;
  my $channel_id = $args{channel_id} || '';
  croak "required channel_id"
    if ( !defined $channel_id or $channel_id eq '' );
  my $page = $args{page} || 1;
  my $data =
    $self->{'wm'}->get("$self->{site_root}/channel/$channel_id?page=$page");
  return $self->_channel_parse($data);
}

sub reply_timeline
{
  my $self   = shift;
  my %args   = @_;
  my $unread = $args{unread_only} || 0;
  if ( $unread == 1 )
  {
    my $data            = $self->{'wm'}->get("$self->{site_root}/my");
    my $new_replay_num  = $self->_get_reply_num($data);
    my $page            = int( $new_replay_num / 30 ) + 1;
    my @time_line_arrey = ();
    for ( 1 .. $page )
    {
      $data =
        $self->{'wm'}->get("$self->{site_root}/my/users_reply/?page=$_");
      my $time_line = $self->_parse($data);
      push @time_line_arrey, @$time_line;
    }
    $#time_line_arrey = $new_replay_num - 1;
    return \@time_line_arrey;
  }
  else
  {
    my $page = $args{page} || 1;
    my $data =
      $self->{'wm'}->get("$self->{site_root}/my/users_reply/?page=$page");
    return $self->_parse($data);
  }
}

sub todo_list
{
  my $self      = shift;
  my $todos_ref = [];
  my $page      = 1;
  while (1)
  {
    my $data = $self->{'wm'}->get("$self->{site_root}/my/todo/?page=$page");
    my $todo_list = $self->_todo_parse($data);
    my $s         = 0;
    eval { $s = scalar(@$todo_list) };
    if ($s)
    {
      push @$todos_ref, @$todo_list;
    }
    else
    {
      last;
    }
    $page++;
  }
  return $todos_ref;
}

sub drunker
{
  my $self = shift;
  my $data = $self->{'wm'}->get("$self->{site_root}/my/drinking_announce/");
  return $self->_drunker_parse($data);
}

sub private_timeline
{
  my $self    = shift;
  my %args    = @_;
  my $user_id = $args{user_id} || '';
  my $page    = $args{page} || 1;
  croak "required user_id" if ( !defined $user_id or $user_id eq '' );
  my $data = $self->{'wm'}->get("$self->{site_root}/user/$user_id");
  my $pad  = $self->_get_user_private_adress($data);
  ( warn q{cant get private_adress.} and return 0 ) if $pad eq '';
  my $pdata = $self->{'wm'}->get( $self->{site_root} . $pad );
  return $self->_private_parse($pdata);
}

sub user_photo {
  my $self    = shift;
  my %args    = @_;
  my $user_id = $args{user_id} || '';
  my $page    = $args{page} || 1;
  croak "required user_id" if ( !defined $user_id or $user_id eq '' );
  my $data = $self->{'wm'}->get("$self->{site_root}/user/$user_id/photos?page=$page");
  return $self->_photo_parse($data);
}

#===parse===
sub _CSRFPROTECT_parse {
  my $self = shift;
  my $data = shift;
  my $scraper = scraper
  {
    process '//form[@id="LoginForm"]/input[1]',
      'csrfprotect' => '@value';
    result 'csrfprotect';
  };
  return $scraper->scrape( $data->{_content} );
}
sub _parse
{
  my $self    = shift;
  my $data    = shift;
  my $scraper = scraper {
    process '//div[@class="MsgBody"]', 'entries[]' => scraper
    {
      process '//p[@class="message description"]', 'description' => ['HTML'];
      process '//a[@class="MsgUserName"]', 'name' => 'TEXT';
      process '//a[@class="MsgDateTime"]',
        'ymdhms'  => 'TEXT',
        'status'  => '@href',
        'message' => '@title';
    };
  };
  my $result    = $scraper->scrape( $data->{_content} );
  my $timelines = $result->{entries};

  my $rmes_scr = scraper
  {
    process 'span>a',
      'rmes' => 'TEXT',
      'rid'  => '@href';
    result 'rmes', 'rid';
  };

  for my $line_wk (@$timelines){
    $line_wk->{status} =~ m{/user/([^/]+)?/statuses/([A-Za-z0-9]{10})};
    $line_wk->{id}     = $1;
    $line_wk->{status} = $2;

    my $rmes = $rmes_scr->scrape( $line_wk->{description} || '' );
    if(defined $rmes->{rid} and $rmes->{rid} ne ''){
      $rmes->{rid} =~ m{/user/([^/]+)/statuses/([A-Za-z0-9]{10})};
      $line_wk->{reply_id}      = $1;
      $line_wk->{reply_status}  = $2;
      $line_wk->{reply_message} = $rmes->{rmes} || '';
    }
  }
  return $timelines;
}

sub _channel_list_parse {
  my $self    = shift;
  my $data    = shift;
  my $scraper = scraper {
    process '//div[@id="ChannelIndex"]/div[@class="OneChannel"]/p[@class="channel-title"]/a', 'urls[]' => '@href';
    result qw/urls/;
  };
  my $result    = $scraper->scrape($data->decoded_content());
  for (@$result){
    $_ = [split m{/}, $_]->[-1];
  }
  return $result;
}

sub _channel_parse
{
  my $self    = shift;
  my $data    = shift;
  my $scraper = scraper
  {
    process 'div.MsgBody>p.messagefoot>a.MsgDateTime',
      'status[]' => '@href',
      'ymdhms[]' => 'TEXT';
    process 'div.MsgBody>p.messagefoot>a.MsgUserName',
      'id[]'   => '@href',
      'name[]' => 'TEXT';
    process 'div.MsgBody>p.message', 'message[]' => 'TEXT';
    result 'message', 'id', 'status', 'ymdhms';
  };
  my $result    = $scraper->scrape( $data->{_content} );
  my $time_line = ();
  for ( 0 .. $#{ $result->{message} } )
  {
    my $line = {};
    my @id = split m{/}, $result->{id}->[$_];
    $line->{id}      = $id[2];
    $line->{message} = $result->{message}->[$_];
    $line->{ymdhms}  = $result->{ymdhms}->[$_];
    push @$time_line, $line;
  }
  return $time_line;
}

sub _get_reply_num
{
  my $self    = shift;
  my $data    = shift;
  my $scraper = scraper
  {
    process 'p#unread_reply_num>a', 'unread_reply_num' => 'TEXT';
    result 'unread_reply_num';
  };
  my $result = $scraper->scrape( $data->{_content} ) || '';
  $result =~ m/未読レスが\s*([0-9]+)\s*件あります/;
  my $unread_reply_num = $1 || 0;
  return $unread_reply_num;
}

sub _follow_parse
{
  my $self    = shift;
  my $data    = shift;
  my $scraper = scraper
  {
    process '//li[@class="line0"]/span[@class="one_user"]', 'usr_o[]' => scraper
    {
      process '//span[@class="user"]/span[@class="user-name"]/a[1]',
        'url'  => '@href',
        'name' => 'TEXT';
      process '//span[@class="message"]/span[@class="date"]',
        'date' => 'TEXT';
      process '//span[@class="message"]',
        'message' => 'TEXT';
      process '//span[@class="etc"]/a[@class="btn-privatetalk"]',
        'pt_url' => '@href';
    };
    process '//li[@class="line1"]/span[@class="one_user"]', 'usr_i[]' => scraper
    {
      process '//span[@class="user"]/span[@class="user-name"]/a[1]',
        'url'  => '@href',
        'name' => 'TEXT';
      process '//span[@class="message"]/span[@class="date"]',
        'date' => 'TEXT';
      process '//span[@class="message"]',
        'message' => 'TEXT';
      process '//span[@class="etc"]/a[@class="btn-privatetalk"]',
        'pt_url' => '@href';
    };
    result 'usr_o','usr_i';
  };
  my $result = $scraper->scrape( $data->{_content} ) || '';
  if(
     (!defined $result->{usr_i} or
               $result->{usr_i} eq '')
     and
     (!defined $result->{usr_o} or
              $result->{usr_o} eq '' )
    ){
    return 0;
  }
  my $users_ref = [];
  for(0..14){
    push @$users_ref,$result->{usr_i}->[$_] if defined $result->{usr_i}->[$_];
    push @$users_ref,$result->{usr_o}->[$_] if defined $result->{usr_o}->[$_];
  }
  for my $usr (@$users_ref) {
    $usr->{name} = $usr->{name};
    $usr->{name} =~ s{\s+}{}g;

    #id parse
    my $id = $usr->{url};
    $id =~ s{/user/}{};
    $usr->{id} = $id;


    #rid, pt_url parse
    $usr->{pt_url} ||= '';
    my $rid = $usr->{pt_url};
    $rid =~ s{/my/love/with\?user_rid=}{};
    $usr->{rid} = $rid;

    #message, last update parse
    my $message = $usr->{message} ||'';
    my $date = $usr->{date} ||'';
    $message =~ s{at\s+[0-9]{4}-[0-9]{2}-[0-9]{2}\([A-Za-z]{3}\)\s+[0-9]{2}:[0-9]{2}:[0-9]{2}}{};
    $message =~ s{^\s+}{}g;
    $message =~ s{\s+$}{}g;
    $usr->{message} = $message;

    $date =~ s{at }{};
    $usr->{ymdhms} = $date;
    delete $usr->{date};
  }
  return $users_ref;
}

sub _drunker_parse
{
  my $self    = shift;
  my $data    = shift;
  my $scraper = scraper
  {
    process 'ul.UserList>li>a', 'id[]' => '@href';
    result 'id';
  };
  my $result = $scraper->scrape( $data->{_content} ) || [];
  s{^/user/}{} for (@$result);
  return $result;
}

sub _get_user_rid
{
  my $self    = shift;
  my $data    = shift;
  my $scraper = scraper
  {
    process 'div.UserSub>form>input',
      'nm[]'  => '@name',
      'val[]' => '@value';
    result 'nm', 'val';
  };
  my $result = $scraper->scrape( $data->{_content} );
  my $rid    = '';
  for ( 0 .. $#{ $result->{nm} } )
  {
    my $rid_wk = $result->{nm}->[$_] || '';
    $rid = $result->{val}->[$_] if $rid_wk eq 'user_rid';
  }
  return $rid;
}

sub _get_to_user_rid
{
  my $self    = shift;
  my $data    = shift;
  my $scraper = scraper
  {
    process 'p.nm>input',
      'nm'  => '@name',
      'val' => '@value';
    result 'nm', 'val';
  };
  my $result   = $scraper->scrape( $data->{_content} );
  my $user_rid = $result->{val};
  return $user_rid;
}

sub _get_user_private_adress
{
  my $self    = shift;
  my $data    = shift;
  my $scraper = scraper
  {
    process 'p.buttons>a#btn-privatetalk', 'path' => '@href';
    result 'path';
  };
  my $result = $scraper->scrape( $data->{_content} );
  if ( !defined $result
    or index( $result, 'user_rid' ) == -1 )
  {
    return '';
  }
  return $result;
}

sub _private_parse
{
  my $self    = shift;
  my $data    = shift;
  my $scraper = scraper
  {
    process 'div.MsgBody>p.messagefoot', 'messagefoot[]' => 'HTML';
    process 'div.MsgBody>p.messagefoot>a',
      'id[]'   => '@href',
      'name[]' => 'TEXT';
    process 'div.MsgBody>p.message', 'message[]' => 'TEXT';
    result 'message', 'id', 'name', 'messagefoot';
  };
  my $result    = $scraper->scrape( $data->{_content} );
  my $time_line = [];
  for ( 0 .. $#{ $result->{message} } )
  {
    my $line = {};
    my @id = split m{/}, $result->{id}->[$_];
    $line->{id}      = $id[2];
    $line->{name}    = $result->{name}->[$_];
    $line->{message} = $result->{message}->[$_];
    my $messagefoot = $result->{messagefoot}->[$_];
    $messagefoot =~
s{^\s+by\s+<a href="$result->{id}->[$_]">$result->{name}->[$_]</a>\s+at\s+}{}; #"
    $line->{ymdhms} = $messagefoot;
    push @$time_line, $line;
  }
  return $time_line;
}

sub _todo_parse
{
  my $self    = shift;
  my $data    = shift;
  my $scraper = scraper
  {
    process 'ul.ToDoList>li>span',
      'tid[]'  => '@id',
      'todo[]' => 'TEXT';
    result 'tid', 'todo';
  };
  my $result = $scraper->scrape( $data->{_content} ) || '';
  my $tlist = ();
  for ( 0 .. $#{ $result->{tid} } )
  {
    my $line = {};
    my $tid  = $result->{tid}->[$_];
    next if !defined $tid or $tid eq '';
    $tid =~ s{^todo_}{};
    $line->{tid}  = $tid;
    $line->{todo} = $result->{todo}->[$_];
    push @$tlist, $line;
  }
  return $tlist;
}

sub _photo_parse {
  my $self    = shift;
  my $html    = shift->decoded_content();
  my $scraper = scraper {
    process '//div[@class="PhotosContainer"]/div[@class="TB_MessageContainer"]', 'data[]' => scraper {
      process '//a', 'status_path[]' => '@href';
      process '//a', message    => '@title';
    };
  };
  my $result = $scraper->scrape($html);
  return if !$result or ref $result ne 'HASH';
  my $data   = $result->{data};
  return if !$data   or ref $data   ne 'ARRAY';

  for my $line (@$data) {
    #postそのものにurlが含まれるとそっちを拾ってくるので、最後のリンクを指定する
    my $status_url = $line->{status_path}->[-1];
    $line->{image_path} = $status_url . '/photo';
    $line->{status_id} = [split m{/}, $status_url]->[-1];
  }
  return $data;
}


#===act===
sub update
{
  my $self    = shift;
  my %args    = @_;
  my $message = $args{status} || '';
  croak "required status" if ( !defined $message or $message eq '' );
  my $id  = $args{user_id}          || '';
  my $rid = $args{reply_status_rid} || '';
  if ( defined $id
    and $id ne ''
    and defined $rid
    and $rid ne '' )
  {
    $self->{'wm'}->get("$self->{site_root}/user/$id/statuses/$rid");
    my $forms           = $self->{'wm'}->forms();
    my $reply_status_id = $forms->[1]->{'inputs'}->[2]->{value};
    $self->{'wm'}->form_number(2);
    my $post = {
      'CSRFPROTECT'     => $self->CSRFPROTECT(),
      'reply_status_id' => $reply_status_id,
      'message'         => $message
    };
    $self->{'wm'}->post( "$self->{site_root}/my/status/add", $post );
  }
  else
  {
    my $post = {
      'CSRFPROTECT' => $self->CSRFPROTECT(),
      'message'     => $message
    };
    $self->{'wm'}->post( "$self->{site_root}/my/status/add", $post );
  }
}

sub channel_update
{
  my $self       = shift;
  my %update     = @_;
  my $channel_id = $update{channel_id};
  my $message    = $update{message};
  $self->{'wm'}->get("$self->{site_root}/channel/$channel_id");
  my $forms       = $self->{'wm'}->forms();
  my $channel_rid = $forms->[1]->{'inputs'}->[2]->{value};
  my $post        = {
    'CSRFPROTECT' => $self->CSRFPROTECT(),
    'body'        => $message,
    'channel_rid' => $channel_rid
  };
  $self->{'wm'}->post( "$self->{site_root}/my/channel/message/add", $post );
}

sub private_update
{
  my $self    = shift;
  my %update  = @_;
  my $user_id = $update{user_id};
  my $message = $update{message};
  croak "required message" if ( !defined $message or $message eq '' );
  croak "required user_id" if ( !defined $user_id or $user_id eq '' );
  my $data = $self->{'wm'}->get("$self->{site_root}/user/$user_id");
  my $pad  = $self->_get_user_private_adress($data);
  $self->{'wm'}->get("$self->{site_root}$pad");
  my $forms       = $self->{'wm'}->forms();
  my $to_user_rid = $forms->[2]->{'inputs'}->[2]->{value};
  my $post        = {
    CSRFPROTECT => $self->CSRFPROTECT(),
    message     => $message,
    to_user_rid => $to_user_rid
  };
  $self->{'wm'}->set_fields();
  $self->{'wm'}->post( "$self->{site_root}/my/love/add", $post );
}

sub favorite_toggle
{
  my $self = shift;
  my %args = @_;
  my $rid  = $args{reply_status_rid} || '';
  if ( defined $rid and $rid ne '' )
  {
    $self->{'wm'}->get("$self->{site_root}/my");
    my $post = {
      status_rid  => $rid,
      CSRFPROTECT => $self->CSRFPROTECT(),
    };
    $self->{'wm'}->post( "$self->{site_root}/my/favorite/toggle", $post );
  }
}

sub delete_status
{
  my $self      = shift;
  my %args      = @_;
  my $status_id = $args{status_id} || '';
  my $post      = { CSRFPROTECT => $self->CSRFPROTECT() };
  $self->{'wm'}
    ->post( "$self->{site_root}/my/delete_status?status_rid=$status_id",
    $post );
}

sub drunk
{
  my $self = shift;
  my $post = { CSRFPROTECT => $self->CSRFPROTECT() };
  $self->{'wm'}->post( "$self->{site_root}/my/drinking_announce/add", $post );
}

sub undrunk
{
  my $self = shift;
  my $post = { CSRFPROTECT => $self->CSRFPROTECT() };
  $self->{'wm'}->post( "$self->{site_root}/my/drinking_announce/delete", $post );
}
1;
__END__

=head1 NAME

WWW::Wassr - Wassr client library for Perl.

=head1 SYNOPSIS

  use WWW::Wassr;
  my $wassr = WWW::Wassr->new(
    user   => 'YOUR LOGIN ID',
    passwd => 'YOUR PASSWORD'
  );
  $wassr->login();
  $wassr->public_timeline();
  $wassr->user_timeline();
  $wassr->sl_timeline();
  $wassr->fav_timeline();
  $wassr->reply_timeline();
  $wassr->todo_list();
  $wassr->follow( FRIEND ID );
  $wassr->unfollow( FRIEND ID );

  $wassr->update(status => 'test');
  $wassr->channel_update(channel_id => 'botest', message => 'channel test');
  $wassr->favorite_toggle(reply_status_rid => 'OqYwctRw5Q');
  $wassr->drunk(); #if you will be drunk tonight


=head1 DESCRIPTION

WWW::Wassr is Wassr client for Perl.

=head1 AUTHOR

  Likkradyus

=head1 SEE ALSO

L<http://wassr.jp/>

=cut
