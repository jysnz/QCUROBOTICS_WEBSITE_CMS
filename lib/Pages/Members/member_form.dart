part of 'members.dart';

class _TeamPlayerFormSheet extends StatefulWidget {
  final _TeamPlayer? player;
  final List<_TeamOption> teams;
  final List<_SeasonOption> seasons;
  final List<_RoleOption> roles;

  const _TeamPlayerFormSheet({
    required this.player,
    required this.teams,
    required this.seasons,
    required this.roles,
  });

  @override
  State<_TeamPlayerFormSheet> createState() => _TeamPlayerFormSheetState();
}

class _TeamPlayerFormSheetState extends State<_TeamPlayerFormSheet> {
  final _supabase = Supabase.instance.client;
  final _imagePicker = ImagePicker();
  final _nameController = TextEditingController();
  final _imageController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  int? _teamId;
  int? _seasonId;
  late bool _isActive;
  late bool _isGraduated;
  late Set<int> _roleIds;
  bool _isSaving = false;
  bool _isUploadingPicture = false;

  String? _initialName;
  String? _initialImageUrl;
  int? _initialTeamId;
  int? _initialSeasonId;
  bool _initialIsActive = true;
  bool _initialIsGraduated = false;
  Set<int> _initialRoleIds = {};

  bool get _hasChanges {
    if (widget.player == null) return true;
    return _nameController.text.trim() != _initialName
        || _imageController.text != _initialImageUrl
        || _teamId != _initialTeamId
        || _seasonId != _initialSeasonId
        || _isActive != _initialIsActive
        || _isGraduated != _initialIsGraduated
        || _roleIds != _initialRoleIds;
  }

  List<_TeamOption> get _teamsForSeason {
    if (_seasonId == null) return const [];
    return widget.teams
        .where((t) => t.seasonId == null || t.seasonId == _seasonId)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    final player = widget.player;
    _nameController.text = player?.name ?? '';
    _imageController.text = player?.imageUrl ?? '';
    _teamId = player?.teamId ?? widget.teams.firstOrNull?.id;
    _seasonId = player?.seasonId ?? widget.seasons.firstOrNull?.id;
    _isActive = player?.isActive ?? true;
    _isGraduated = player?.isGraduated ?? false;
    _roleIds = widget.roles
        .where((role) => player?.roles.contains(role.name) ?? false)
        .map((role) => role.id)
        .whereType<int>()
        .toSet();
    _initialName = player?.name ?? '';
    _initialImageUrl = player?.imageUrl ?? '';
    _initialTeamId = player?.teamId;
    _initialSeasonId = player?.seasonId;
    _initialIsActive = player?.isActive ?? true;
    _initialIsGraduated = player?.isGraduated ?? false;
    _initialRoleIds = Set.from(_roleIds);
    if (widget.player != null) {
      _nameController.addListener(_onFieldChanged);
      _imageController.addListener(_onFieldChanged);
    }
  }

  void _onFieldChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _nameController.removeListener(_onFieldChanged);
    _imageController.removeListener(_onFieldChanged);
    _nameController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_teamId == null || _seasonId == null) {
      _showError('Select a team and season first.');
      return;
    }

    setState(() => _isSaving = true);
    final isEditing = widget.player != null;
    try {
      final payload = {
        'name': _nameController.text.trim(),
        'profile_image_url': _nullableString(_imageController.text),
        'is_active': _isActive,
        'is_graduated': _isGraduated,
      };

      final player = widget.player;
      late final int memberId;
      if (player == null) {
        final inserted = await _supabase
            .from('team_members')
            .insert(payload)
            .select('id')
            .single();
        memberId = _intValue(inserted['id'])!;
      } else {
        memberId = player.id;
        await _supabase.from('team_members').update(payload).eq('id', memberId);
      }

      final assignmentPayload = {
        'member_id': memberId,
        'team_id': _teamId,
        'season_id': _seasonId,
      };
      if (player?.assignmentId == null) {
        await _supabase.from('member_team_seasons').insert(assignmentPayload);
      } else {
        final assignmentId = player!.assignmentId!;
        await _supabase
            .from('member_team_seasons')
            .update(assignmentPayload)
            .eq('id', assignmentId);
      }

      await _supabase
          .from('member_roles')
          .delete()
          .eq('member_id', memberId)
          .eq('season_id', _seasonId!);
      if (_roleIds.isNotEmpty) {
        await _supabase.from('member_roles').insert([
          for (final roleId in _roleIds)
            {
              'member_id': memberId,
              'role_id': roleId,
              'season_id': _seasonId,
            },
        ]);
      }

      if (mounted) {
        await _showSuccess(
          message: isEditing ? 'Member updated.' : 'Member added.',
          imageUrl: _nullableString(_imageController.text),
        );
        if (mounted) Navigator.of(context).pop(true);
      }
    } catch (error) {
      _showError(error.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickProfilePicture() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    if (image == null) return;

    setState(() => _isUploadingPicture = true);
    try {
      final name = _nameController.text.trim();
      final url = await StorageService.uploadMemberPicture(
        supabase: _supabase,
        image: image,
        folder: 'team_players',
        personName: name.isEmpty ? DateTime.now().microsecondsSinceEpoch.toString() : name,
      );

      if (mounted) {
        final confirmed = await showPhotoConfirmDialog(
          context: context,
          url: url,
          name: name.isEmpty ? 'Member' : name,
        );
        if (confirmed == true) {
          _imageController.text = url;
          if (widget.player != null) {
            await _supabase
                .from('team_members')
                .update({'profile_image_url': url})
                .eq('id', widget.player!.id);
          }
        }
      }
    } catch (error) {
      _showError(error.toString());
    } finally {
      if (mounted) setState(() => _isUploadingPicture = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFB91C1C),
      ),
    );
  }

  Future<void> _showSuccess({required String message, String? imageUrl}) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline_rounded, color: kAccent, size: 24),
            SizedBox(width: 10),
            Text('Success', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (imageUrl != null) ...[
              ClipOval(
                child: Image.network(
                  imageUrl,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(message, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK', style: TextStyle(color: kAccent, fontWeight: FontWeight.w800, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.player != null;
    return _FormSheetScaffold(
      title: isEditing ? 'Edit Member' : 'Add Member',
      isSaving: _isSaving,
      canSave: _hasChanges,
      onSave: _save,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _TextFieldInput(
              controller: _nameController,
              label: 'Name',
              validator: _requiredValidator,
            ),
            const SizedBox(height: 12),
            _PhotoPickerInput(
              imageUrl: _nullableString(_imageController.text),
              isUploading: _isUploadingPicture,
              onPick: _pickProfilePicture,
            ),
            const SizedBox(height: 12),
            _DropdownInput<int>(
              label: 'Team',
              initialValue: _teamsForSeason.any((t) => t.id == _teamId) ? _teamId : null,
              items: [
                for (final team in _teamsForSeason)
                  DropdownMenuItem(value: team.id, child: Text(team.name.toUpperCase())),
              ],
              onChanged: (value) => setState(() => _teamId = value),
            ),
            if (!isEditing) ...[
              const SizedBox(height: 12),
              _DropdownInput<int>(
                label: 'Season',
                initialValue: _seasonId,
                items: [
                  for (final season in widget.seasons)
                    DropdownMenuItem(value: season.id, child: Text(season.name.toUpperCase())),
                ],
                onChanged: (value) {
                  setState(() {
                    _seasonId = value;
                    if (!_teamsForSeason.any((t) => t.id == _teamId)) {
                      _teamId = _teamsForSeason.firstOrNull?.id;
                    }
                  });
                },
              ),
            ],
            const SizedBox(height: 10),
            _SwitchInput(
              label: 'Active',
              value: _isActive,
              onChanged: (value) => setState(() => _isActive = value),
            ),
            _SwitchInput(
              label: 'Graduated',
              value: _isGraduated,
              onChanged: (value) => setState(() => _isGraduated = value),
            ),
            const SizedBox(height: 10),
            _RoleSelector(
              roles: widget.roles,
              selectedIds: _roleIds,
              onChanged: (ids) => setState(() => _roleIds = ids),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaMemberFormSheet extends StatefulWidget {
  final Map<String, dynamic>? row;

  const _MediaMemberFormSheet({required this.row});

  @override
  State<_MediaMemberFormSheet> createState() => _MediaMemberFormSheetState();
}

class _MediaMemberFormSheetState extends State<_MediaMemberFormSheet> {
  final _supabase = Supabase.instance.client;
  final _imagePicker = ImagePicker();
  final _nameController = TextEditingController();
  final _positionController = TextEditingController();
  final _imageController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late bool _isActive;
  bool _isSaving = false;
  bool _isUploadingPicture = false;

  String? _initialName;
  String? _initialPosition;
  String? _initialImageUrl;
  bool _initialIsActive = true;

  bool get _hasChanges {
    if (widget.row == null) return true;
    return _nameController.text.trim() != _initialName
        || _positionController.text.trim() != _initialPosition
        || _imageController.text != _initialImageUrl
        || _isActive != _initialIsActive;
  }

  @override
  void initState() {
    super.initState();
    final row = widget.row;
    _nameController.text = _stringValue(row?['name']);
    _positionController.text = _stringValue(row?['position']);
    _imageController.text = _stringValue(row?['image_url']);
    _isActive = row?['is_active'] == true || row == null;
    _initialName = _stringValue(row?['name']);
    _initialPosition = _stringValue(row?['position']);
    _initialImageUrl = _stringValue(row?['image_url']);
    _initialIsActive = row?['is_active'] == true || row == null;
    if (widget.row != null) {
      _nameController.addListener(_onFieldChanged);
      _positionController.addListener(_onFieldChanged);
      _imageController.addListener(_onFieldChanged);
    }
  }

  void _onFieldChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _nameController.removeListener(_onFieldChanged);
    _positionController.removeListener(_onFieldChanged);
    _imageController.removeListener(_onFieldChanged);
    _nameController.dispose();
    _positionController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final isEditing = widget.row != null;
    try {
      final payload = {
        'name': _nameController.text.trim(),
        'position': _nullableString(_positionController.text),
        'image_url': _nullableString(_imageController.text),
        'is_active': _isActive,
      };
      final id = _intValue(widget.row?['id']);
      if (id == null) {
        await _supabase.from('media_team').insert(payload);
      } else {
        await _supabase.from('media_team').update(payload).eq('id', id);
      }
      if (mounted) {
        await _showSuccess(
          message: isEditing ? 'Member updated.' : 'Member added.',
          imageUrl: _nullableString(_imageController.text),
        );
        if (mounted) Navigator.of(context).pop(true);
      }
    } catch (error) {
      _showError(error.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickProfilePicture() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    if (image == null) return;

    setState(() => _isUploadingPicture = true);
    try {
      final name = _nameController.text.trim();
      final url = await StorageService.uploadMemberPicture(
        supabase: _supabase,
        image: image,
        folder: 'media_team',
        personName: name.isEmpty ? DateTime.now().microsecondsSinceEpoch.toString() : name,
      );

      if (mounted) {
        final confirmed = await showPhotoConfirmDialog(
          context: context,
          url: url,
          name: name.isEmpty ? 'Media Member' : name,
        );
        if (confirmed == true) {
          _imageController.text = url;
          if (widget.row != null) {
            final id = _intValue(widget.row!['id']);
            if (id != null) {
              await _supabase
                  .from('media_team')
                  .update({'image_url': url})
                  .eq('id', id);
            }
          }
        }
      }
    } catch (error) {
      _showError(error.toString());
    } finally {
      if (mounted) setState(() => _isUploadingPicture = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFB91C1C),
      ),
    );
  }

  Future<void> _showSuccess({required String message, String? imageUrl}) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline_rounded, color: kAccent, size: 24),
            SizedBox(width: 10),
            Text('Success', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (imageUrl != null) ...[
              ClipOval(
                child: Image.network(
                  imageUrl,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(message, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK', style: TextStyle(color: kAccent, fontWeight: FontWeight.w800, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.row != null;
    return _FormSheetScaffold(
      title: isEditing ? 'Edit Member' : 'Add Member',
      isSaving: _isSaving,
      canSave: _hasChanges,
      onSave: _save,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _TextFieldInput(
              controller: _nameController,
              label: 'Name',
              validator: _requiredValidator,
            ),
            const SizedBox(height: 12),
            _TextFieldInput(controller: _positionController, label: 'Position'),
            const SizedBox(height: 12),
            _PhotoPickerInput(
              imageUrl: _nullableString(_imageController.text),
              isUploading: _isUploadingPicture,
              onPick: _pickProfilePicture,
            ),
            const SizedBox(height: 10),
            _SwitchInput(
              label: 'Active',
              value: _isActive,
              onChanged: (value) => setState(() => _isActive = value),
            ),
          ],
        ),
      ),
    );
  }
}

class _GenericMemberFormSheet extends StatefulWidget {
  final Map<String, dynamic>? row;

  const _GenericMemberFormSheet({required this.row});

  @override
  State<_GenericMemberFormSheet> createState() =>
      _GenericMemberFormSheetState();
}

class _GenericMemberFormSheetState extends State<_GenericMemberFormSheet> {
  final _supabase = Supabase.instance.client;
  final _imagePicker = ImagePicker();
  final _nameController = TextEditingController();
  final _subtitleController = TextEditingController();
  final _imageController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late final String _nameKey;
  late final String? _subtitleKey;
  late final String? _imageKey;
  late bool _isActive;
  bool _isSaving = false;
  bool _isUploadingPicture = false;

  String? _initialName;
  String? _initialSubtitle;
  String? _initialImageUrl;
  bool _initialIsActive = true;

  bool get _hasChanges {
    if (widget.row == null) return true;
    if (_nameController.text.trim() != _initialName) return true;
    if (_imageController.text != _initialImageUrl) return true;
    if (_isActive != _initialIsActive) return true;
    if (_subtitleKey != null && _subtitleController.text.trim() != _initialSubtitle) return true;
    return false;
  }

  @override
  void initState() {
    super.initState();
    final row = widget.row;
    _nameKey =
        _firstExistingKey(row, ['name', 'full_name', 'username', 'email']) ??
        'name';
    _subtitleKey = _firstExistingKey(row, [
      'role',
      'position',
      'email',
      'status',
    ]);
    _imageKey =
        _firstExistingKey(row, [
          'profile_image_url',
          'image_url',
          'avatar_url',
        ]) ??
        'image_url';
    _nameController.text = _stringValue(row?[_nameKey]);
    if (_subtitleKey != null) {
      _subtitleController.text = _stringValue(row?[_subtitleKey]);
    }
    if (_imageKey != null) {
      _imageController.text = _stringValue(row?[_imageKey]);
    }
    _isActive = row?['is_active'] == true || row == null;
    _initialName = _stringValue(row?[_nameKey]);
    _initialSubtitle = _subtitleKey != null ? _stringValue(row?[_subtitleKey]) : null;
    _initialImageUrl = _imageKey != null ? _stringValue(row?[_imageKey]) : null;
    _initialIsActive = row?['is_active'] == true || row == null;
    if (widget.row != null) {
      _nameController.addListener(_onFieldChanged);
      _imageController.addListener(_onFieldChanged);
      if (_subtitleKey != null) {
        _subtitleController.addListener(_onFieldChanged);
      }
    }
  }

  void _onFieldChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _nameController.removeListener(_onFieldChanged);
    _imageController.removeListener(_onFieldChanged);
    if (_subtitleKey != null) {
      _subtitleController.removeListener(_onFieldChanged);
    }
    _nameController.dispose();
    _subtitleController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final isEditing = widget.row != null;
    try {
      final payload = <String, dynamic>{_nameKey: _nameController.text.trim()};
      final imageKey = _imageKey;
      if (imageKey != null) {
        payload[imageKey] = _nullableString(_imageController.text);
      }

      if (widget.row != null) {
        final subtitleKey = _subtitleKey;
        if (subtitleKey != null) {
          payload[subtitleKey] = _nullableString(_subtitleController.text);
        }
        if (widget.row!.containsKey('is_active')) {
          payload['is_active'] = _isActive;
        }
      }

      final id = _intValue(widget.row?['id']);
      if (id == null) {
        await _supabase.from('members').insert(payload);
      } else {
        await _supabase.from('members').update(payload).eq('id', id);
      }
      if (mounted) {
        await _showSuccess(
          message: isEditing ? 'Member updated.' : 'Member added.',
          imageUrl: _nullableString(_imageController.text),
        );
        if (mounted) Navigator.of(context).pop(true);
      }
    } catch (error) {
      _showError(error.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickProfilePicture() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    if (image == null) return;

    setState(() => _isUploadingPicture = true);
    try {
      final name = _nameController.text.trim();
      final url = await StorageService.uploadMemberPicture(
        supabase: _supabase,
        image: image,
        folder: 'members',
        personName: name.isEmpty ? DateTime.now().microsecondsSinceEpoch.toString() : name,
      );

      if (mounted) {
        final confirmed = await showPhotoConfirmDialog(
          context: context,
          url: url,
          name: name.isEmpty ? 'Member' : name,
        );
        if (confirmed == true) {
          _imageController.text = url;
          if (widget.row != null) {
            final id = _intValue(widget.row!['id']);
            if (id != null) {
              await _supabase
                  .from('members')
                  .update({_imageKey!: url})
                  .eq('id', id);
            }
          }
        }
      }
    } catch (error) {
      _showError(error.toString());
    } finally {
      if (mounted) setState(() => _isUploadingPicture = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFB91C1C),
      ),
    );
  }

  Future<void> _showSuccess({required String message, String? imageUrl}) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline_rounded, color: kAccent, size: 24),
            SizedBox(width: 10),
            Text('Success', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (imageUrl != null) ...[
              ClipOval(
                child: Image.network(
                  imageUrl,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(message, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK', style: TextStyle(color: kAccent, fontWeight: FontWeight.w800, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.row != null;
    return _FormSheetScaffold(
      title: isEditing ? 'Edit Member' : 'Add Member',
      isSaving: _isSaving,
      canSave: _hasChanges,
      onSave: _save,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _TextFieldInput(
              controller: _nameController,
              label: 'Name',
              validator: _requiredValidator,
            ),
            if (_subtitleKey case final subtitleKey?) ...[
              const SizedBox(height: 12),
              _TextFieldInput(
                controller: _subtitleController,
                label: _fieldLabel(subtitleKey),
              ),
            ],
            if (_imageKey case final imageKey?) ...[
              const SizedBox(height: 12),
              _PhotoPickerInput(
                imageUrl: _nullableString(_imageController.text),
                isUploading: _isUploadingPicture,
                onPick: _pickProfilePicture,
              ),
            ],
            if (widget.row?.containsKey('is_active') ?? false) ...[
              const SizedBox(height: 10),
              _SwitchInput(
                label: 'Active Status',
                value: _isActive,
                onChanged: (value) => setState(() => _isActive = value),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CoachFormSheet extends StatefulWidget {
  final Map<String, dynamic>? row;

  const _CoachFormSheet({required this.row});

  @override
  State<_CoachFormSheet> createState() => _CoachFormSheetState();
}

class _CoachFormSheetState extends State<_CoachFormSheet> {
  final _supabase = Supabase.instance.client;
  final _imagePicker = ImagePicker();
  final _nameController = TextEditingController();
  final _imageController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late bool _isActive;
  bool _isSaving = false;
  bool _isUploadingPicture = false;

  String? _initialName;
  String? _initialImageUrl;
  bool _initialIsActive = true;

  bool get _hasChanges {
    if (widget.row == null) return true;
    return _nameController.text.trim() != _initialName
        || _imageController.text != _initialImageUrl
        || _isActive != _initialIsActive;
  }

  @override
  void initState() {
    super.initState();
    final row = widget.row;
    _nameController.text = _stringValue(row?['name']);
    _imageController.text = _stringValue(row?['image_url']);
    _isActive = row?['is_active'] == true || row == null;
    _initialName = _stringValue(row?['name']);
    _initialImageUrl = _stringValue(row?['image_url']);
    _initialIsActive = row?['is_active'] == true || row == null;
    if (widget.row != null) {
      _nameController.addListener(_onFieldChanged);
      _imageController.addListener(_onFieldChanged);
    }
  }

  void _onFieldChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _nameController.removeListener(_onFieldChanged);
    _imageController.removeListener(_onFieldChanged);
    _nameController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final isEditing = widget.row != null;
    try {
      final payload = {
        'name': _nameController.text.trim(),
        'image_url': _nullableString(_imageController.text),
        'is_active': _isActive,
      };
      final id = _intValue(widget.row?['id']);
      if (id == null) {
        await _supabase.from('Coaches').insert(payload);
      } else {
        await _supabase.from('Coaches').update(payload).eq('id', id);
      }
      if (mounted) {
        await _showSuccess(
          message: isEditing ? 'Coach updated.' : 'Coach added.',
          imageUrl: _nullableString(_imageController.text),
        );
        if (mounted) Navigator.of(context).pop(true);
      }
    } catch (error) {
      _showError(error.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickProfilePicture() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    if (image == null) return;

    setState(() => _isUploadingPicture = true);
    try {
      final name = _nameController.text.trim();
      final url = await StorageService.uploadMemberPicture(
        supabase: _supabase,
        image: image,
        folder: 'coaches',
        personName: name.isEmpty ? DateTime.now().microsecondsSinceEpoch.toString() : name,
      );

      if (mounted) {
        final confirmed = await showPhotoConfirmDialog(
          context: context,
          url: url,
          name: name.isEmpty ? 'Coach' : name,
        );
        if (confirmed == true) {
          _imageController.text = url;
          if (widget.row != null) {
            final id = _intValue(widget.row!['id']);
            if (id != null) {
              await _supabase
                  .from('Coaches')
                  .update({'image_url': url})
                  .eq('id', id);
            }
          }
        }
      }
    } catch (error) {
      _showError(error.toString());
    } finally {
      if (mounted) setState(() => _isUploadingPicture = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFB91C1C),
      ),
    );
  }

  Future<void> _showSuccess({required String message, String? imageUrl}) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline_rounded, color: kAccent, size: 24),
            SizedBox(width: 10),
            Text('Success', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (imageUrl != null) ...[
              ClipOval(
                child: Image.network(
                  imageUrl,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(message, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK', style: TextStyle(color: kAccent, fontWeight: FontWeight.w800, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.row != null;
    return _FormSheetScaffold(
      title: isEditing ? 'Edit Coach' : 'Add Coach',
      isSaving: _isSaving,
      canSave: _hasChanges,
      onSave: _save,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _TextFieldInput(
              controller: _nameController,
              label: 'Name',
              validator: _requiredValidator,
            ),
            const SizedBox(height: 12),
            _PhotoPickerInput(
              imageUrl: _nullableString(_imageController.text),
              isUploading: _isUploadingPicture,
              onPick: _pickProfilePicture,
            ),
            const SizedBox(height: 10),
            _SwitchInput(
              label: 'Active Status',
              value: _isActive,
              onChanged: (value) => setState(() => _isActive = value),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormSheetScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final bool isSaving;
  final VoidCallback onSave;
  final bool canSave;

  const _FormSheetScaffold({
    required this.title,
    required this.child,
    required this.isSaving,
    required this.onSave,
    this.canSave = true,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, color: Colors.white38),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: child,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: TechnicalButton(
                  label: isSaving ? 'Saving...' : 'Save',
                  onTap: (isSaving || !canSave) ? () {} : onSave,
                  isLoading: isSaving,
                  color: canSave ? kAccent : Colors.white24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TextFieldInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;

  const _TextFieldInput({
    required this.controller,
    required this.label,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
      decoration: _inputDecoration(label),
    );
  }
}

class _PhotoPickerInput extends StatelessWidget {
  final String? imageUrl;
  final bool isUploading;
  final VoidCallback onPick;

  const _PhotoPickerInput({
    required this.imageUrl,
    required this.isUploading,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return TechnicalCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          _Avatar(imageUrl: imageUrl, name: 'USER', size: 44),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profile Image',
                  style: TextStyle(
                    color: Colors.white24,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Change Photo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          _SmallIconButton(
            icon: isUploading
                ? Icons.sync_rounded
                : Icons.add_a_photo_outlined,
            color: kAccent,
            onTap: isUploading ? () {} : onPick,
          ),
        ],
      ),
    );
  }
}

class _DropdownInput<T> extends StatelessWidget {
  final String label;
  final T? initialValue;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _DropdownInput({
    required this.label,
    required this.initialValue,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: initialValue,
      items: items,
      onChanged: onChanged,
      isExpanded: true,
      dropdownColor: kSurface,
      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
      decoration: _inputDecoration(label),
    );
  }
}

class _SwitchInput extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchInput({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
      title: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
      activeThumbColor: kAccent,
    );
  }
}

class _RoleSelector extends StatelessWidget {
  final List<_RoleOption> roles;
  final Set<int> selectedIds;
  final ValueChanged<Set<int>> onChanged;

  const _RoleSelector({
    required this.roles,
    required this.selectedIds,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (roles.isEmpty) {
      return Text(
        'NO ROLES DEFINED',
        style: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 11, fontWeight: FontWeight.w800),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TechnicalSectionHeader(label: 'Assigned Roles', color: kAccent, topPadding: 12),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final role in roles)
              Builder(
                builder: (context) {
                  final isSelected = selectedIds.contains(role.id);
                  return FilterChip(
                    label: Text(
                      role.name.toUpperCase(),
                      style: TextStyle(
                        color: isSelected ? kBackground : Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      final id = role.id;
                      if (id == null) return;
                      final next = Set<int>.from(selectedIds);
                      if (selected) {
                        next.add(id);
                      } else {
                        next.remove(id);
                      }
                      onChanged(next);
                    },
                    selectedColor: kAccent,
                    backgroundColor: kSurface.withValues(alpha: 0.5),
                    checkmarkColor: kBackground,
                    side: BorderSide(
                      color: isSelected ? kAccent : Colors.white.withValues(alpha: 0.05),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                },
              ),
          ],
        ),
      ],
    );
  }
}
