import 'package:connect_ed_2/classes/team.dart';
import 'package:connect_ed_2/classes/standings_list.dart';
import 'package:connect_ed_2/frontend/sports/team_widget.dart';
import 'package:connect_ed_2/requests/standings_cache_manager.dart';
import 'package:flutter/material.dart';

class TeamsSearchPage extends StatefulWidget {
  const TeamsSearchPage({super.key});

  @override
  State<TeamsSearchPage> createState() => _TeamsSearchPageState();
}

class _TeamsSearchPageState extends State<TeamsSearchPage> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  // Teams data storage
  Map<String, StandingsList>? _standingsData;
  List<Team> _allTeams = [];
  List<Team> _filteredTeams = [];
  bool _isLoading = true;
  bool _hasLoadError = false;
  String? _errorMessage;

  final Duration _animationDuration = const Duration(milliseconds: 600);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_updateFilteredTeams);
    _loadTeamsData();
  }

  @override
  void dispose() {
    _searchController.removeListener(_updateFilteredTeams);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // Load teams data from standings cache manager
  Future<void> _loadTeamsData() async {
    setState(() {
      _isLoading = true;
      _hasLoadError = false;
    });

    try {
      // Try to get cached data first
      Map<String, StandingsList>? cachedStandings;
      try {
        cachedStandings = standingsManager.getCachedData();
      } catch (e) {
        print('Error accessing cached standings: $e');
      }

      // If no cached data, fetch fresh data
      cachedStandings ??= await standingsManager.fetchData();

      // Process the teams data
      setState(() {
        _standingsData = cachedStandings;
        _extractTeams();
        _updateFilteredTeams();
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _isLoading = false;
        _hasLoadError = true;
        _errorMessage = error.toString();
      });
      print('Error loading teams data: $error');
    }
  }

  // Extract all Appleby teams from standings data
  void _extractTeams() {
    _allTeams = [];

    if (_standingsData != null) {
      _standingsData!.forEach((leagueCode, standingsList) {
        // Add team if it exists
        // Use sport name instead of school name
        final sportName = standingsList.sportsName;
        Team team = standingsList.applebyTeam;

        // Create new team with sport name instead of "Appleby College"
        _allTeams.add(
          Team(
            name: sportName,
            rank: team.rank,
            record: team.record,
            sportIcon: team.sportIcon,
            leagueCode: leagueCode,
          ),
        );
      });

      // Sort teams by rank (best performing first)
      _allTeams.sort((a, b) => a.rank.compareTo(b.rank));
    }
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (_isSearching) {
        _searchFocusNode.requestFocus();
      } else {
        _searchController.clear();
        _searchFocusNode.unfocus();
      }
    });
  }

  void _updateFilteredTeams() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredTeams =
          _allTeams.where((team) {
            return query.isEmpty || team.name.toLowerCase().contains(query);
          }).toList();
    });
  }

  Widget _buildNormalFlexibleSpace(
    BuildContext context,
    ThemeData theme, {
    Key? key,
  }) {
    const String pageTitle = 'Teams';
    return LayoutBuilder(
      key: key,
      builder: (BuildContext context, BoxConstraints constraints) {
        double progress = 1.0;
        double height = constraints.maxHeight;
        final double collapsedHeight =
            MediaQuery.of(context).padding.top + 35.0;
        final double expandedAppBarHeight = 75.0;

        if (height > collapsedHeight) {
          final double maxHeight =
              expandedAppBarHeight + MediaQuery.of(context).padding.top;
          progress = (maxHeight - height) / (maxHeight - collapsedHeight);
        }
        progress = progress.clamp(0.0, 1.0);

        final largeTitleOpacity = (1.0 - progress).clamp(0.0, 1.0);
        final smallTitleOpacity = progress.clamp(0.0, 1.0);

        return Container(
          color: theme.colorScheme.surface,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Large title
              Positioned(
                bottom: 16.0,
                left: 16.0,
                right: 16.0,
                child: Opacity(
                  opacity: largeTitleOpacity,
                  child: Row(
                    children: [
                      // Back button
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back_ios,
                          size: 24,
                          color: theme.colorScheme.onSurface,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      // Title text
                      Expanded(
                        child: Text(
                          pageTitle,
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.search,
                          size: 24,
                          color: theme.colorScheme.onSurface,
                        ),
                        onPressed: _toggleSearch,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ),
              // Small title
              Positioned(
                top: MediaQuery.of(context).padding.top - 4,
                left: 0,
                right: 0,
                child: AnimatedOpacity(
                  opacity: smallTitleOpacity,
                  duration: const Duration(milliseconds: 100),
                  child: Flex(
                    direction: Axis.horizontal,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        fit: FlexFit.tight,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_ios, size: 18),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      Flexible(
                        flex: 5,
                        fit: FlexFit.tight,
                        child: Text(
                          'Teams',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Flexible(fit: FlexFit.tight, child: SizedBox.shrink()),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Method to build the flexible space for search mode
  Widget _buildSearchFlexibleSpace(
    BuildContext context,
    ThemeData theme, {
    Key? key,
  }) {
    return LayoutBuilder(
      key: key,
      builder: (BuildContext context, BoxConstraints constraints) {
        double progress = 1.0;
        double height = constraints.maxHeight;
        final double collapsedHeight =
            MediaQuery.of(context).padding.top + 35.0;
        final double expandedAppBarHeight = 75.0;

        if (height > collapsedHeight) {
          final double maxHeight =
              expandedAppBarHeight + MediaQuery.of(context).padding.top;
          progress = (maxHeight - height) / (maxHeight - collapsedHeight);
        }
        progress = progress.clamp(0.0, 1.0);

        final expandedOpacity = (1.0 - progress).clamp(0.0, 1.0);
        final collapsedOpacity = progress.clamp(0.0, 1.0);

        return Container(
          color: theme.colorScheme.surface,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Back button for both expanded and collapsed states
              Positioned(
                bottom: 17.0,
                left: 16.0,
                right: 16.0,
                child: Opacity(
                  opacity: expandedOpacity,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back_ios,
                          size: 24,
                          color: theme.colorScheme.onSurface,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: 'Search teams...',
                            border: InputBorder.none,
                            hintStyle: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 0,
                              horizontal: 0,
                            ),
                          ),
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          size: 24,
                          color: theme.colorScheme.onSurface,
                        ),
                        onPressed: _toggleSearch,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ),
              // Collapsed search text
              Positioned(
                top: MediaQuery.of(context).padding.top - 4,
                left: 0,
                right: 0,
                child: AnimatedOpacity(
                  opacity: collapsedOpacity,
                  duration: const Duration(milliseconds: 100),
                  child: Flex(
                    direction: Axis.horizontal,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        fit: FlexFit.tight,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_ios, size: 18),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      Flexible(
                        flex: 5,
                        fit: FlexFit.tight,
                        child: Text(
                          _searchController.text.isEmpty
                              ? 'Search'
                              : ' "${_searchController.text}" in teams',
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Flexible(fit: FlexFit.tight, child: SizedBox.shrink()),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: theme.colorScheme.surface,
            elevation: 0,
            toolbarHeight: 35.0,
            expandedHeight: 75.0,
            automaticallyImplyLeading: false,
            leadingWidth: 0,
            titleSpacing: 0,
            title: null,
            flexibleSpace: AnimatedSwitcher(
              duration: _animationDuration,
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child:
                  _isSearching
                      ? _buildSearchFlexibleSpace(
                        context,
                        theme,
                        key: const ValueKey('search_flexible_space'),
                      )
                      : _buildNormalFlexibleSpace(
                        context,
                        theme,
                        key: const ValueKey('normal_flexible_space'),
                      ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver:
                _isLoading
                    ? SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    )
                    : _hasLoadError
                    ? SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 48,
                              color: theme.colorScheme.error,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Failed to load teams',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.error,
                              ),
                            ),
                            SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: _loadTeamsData,
                              child: Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                    : _filteredTeams.isEmpty
                    ? SliverFillRemaining(
                      child: Center(
                        child: Text(
                          _searchController.text.isNotEmpty
                              ? 'No teams match your search.'
                              : 'No teams available.',
                          style: TextStyle(
                            fontSize: 16,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                    : SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16.0,
                            mainAxisSpacing: 16.0,
                            mainAxisExtent: 190.0,
                          ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) =>
                            TeamWidget(team: _filteredTeams[index]),
                        childCount: _filteredTeams.length,
                      ),
                    ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
          ),
        ],
      ),
    );
  }
}
