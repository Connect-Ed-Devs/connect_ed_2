import 'package:connect_ed_2/classes/game.dart';
import 'package:connect_ed_2/frontend/sports/game_widgets.dart';
import 'package:flutter/material.dart';

class GameSearchPage extends StatefulWidget {
  final String? initialFilter; // 'upcoming' or 'played'

  const GameSearchPage({super.key, this.initialFilter});

  @override
  State<GameSearchPage> createState() => _GameSearchPageState();
}

class _GameSearchPageState extends State<GameSearchPage> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  Set<String> _selectedSeasonChips = {};
  Set<String> _selectedStatusChips = {};

  final List<String> _seasonOptions = ["Fall", "Winter", "Spring"];
  final List<String> _statusOptions = ["Played", "Upcoming"];

  // Dummy game data
  final List<Game> _allGames = List.generate(
    20,
    (index) => Game(
      homeTeam: "Team ${String.fromCharCode(65 + index)}",
      homeabbr: "T${String.fromCharCode(65 + index)}",
      homeLogo: "assets/team_a_logo.png",
      awayTeam: "Team ${String.fromCharCode(85 + index)}",
      awayabbr: "T${String.fromCharCode(85 + index)}",
      awayLogo: "assets/team_b_logo.png",
      date: DateTime.now().add(Duration(days: (index - 10) * 3)), // Mix of past and future
      time: "${(index % 12) + 1}:00 PM",
      homeScore: (index % 3 == 0 && index <= 10) ? "${20 + index}" : "-", // Scores for some past games
      awayScore: (index % 3 == 0 && index <= 10) ? "${18 + index}" : "-",
      sportsID: index % 5,
      sportsName: ["Football", "Basketball", "Soccer", "Volleyball", "Baseball"][index % 5],
      term: ["Fall 2023", "Winter 2023", "Spring 2024", "Fall 2024", "Winter 2024"][index % 5],
      leagueCode: "NCAA",
    ),
  );

  List<Game> _filteredGames = [];
  final Duration _animationDuration = const Duration(milliseconds: 600); // Longer animation duration

  @override
  void initState() {
    super.initState();

    // Apply initial filter if provided
    if (widget.initialFilter != null) {
      switch (widget.initialFilter) {
        case 'upcoming':
          _selectedStatusChips.add("Upcoming");
          break;
        case 'played':
          _selectedStatusChips.add("Played");
          break;
      }
    }

    _filteredGames = _allGames;
    _searchController.addListener(_updateFilteredGames);

    // Trigger initial filtering to apply the selected chip
    _updateFilteredGames();
  }

  @override
  void dispose() {
    _searchController.removeListener(_updateFilteredGames);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
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

  void _updateFilteredGames() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredGames =
          _allGames.where((game) {
            final bool matchesSearch =
                query.isEmpty ||
                game.homeTeam.toLowerCase().contains(query) ||
                game.awayTeam.toLowerCase().contains(query) ||
                game.sportsName.toLowerCase().contains(query);

            final bool matchesSeason =
                _selectedSeasonChips.isEmpty ||
                _selectedSeasonChips.any((season) => game.term.toLowerCase().contains(season.toLowerCase()));

            final bool matchesStatus =
                _selectedStatusChips.isEmpty ||
                _selectedStatusChips.any((status) {
                  if (status == "Played") {
                    return game.homeScore != "-" && game.awayScore != "-";
                  }
                  if (status == "Upcoming") {
                    return (game.homeScore == "-" && game.awayScore == "-") || game.date.isAfter(DateTime.now());
                  }
                  return false;
                });

            return matchesSearch && matchesSeason && matchesStatus;
          }).toList();
    });
  }

  Widget _buildChip(String label, Set<String> selectedSet) {
    final bool isSelected = selectedSet.contains(label);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0), // Reduced horizontal padding
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (bool selected) {
          setState(() {
            if (selected) {
              selectedSet.add(label);
            } else {
              selectedSet.remove(label);
            }
            _updateFilteredGames();
          });
        },
        backgroundColor: theme.colorScheme.surfaceVariant.withOpacity(0.5),
        selectedColor: theme.colorScheme.primary,
        labelStyle: TextStyle(
          fontSize: 12, // Set font size to 12
          color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0), // Reduced internal padding
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        checkmarkColor: theme.colorScheme.onPrimary,
      ),
    );
  }

  Widget _buildNormalFlexibleSpace(BuildContext context, ThemeData theme, {Key? key}) {
    const String pageTitle = "Games";
    return LayoutBuilder(
      key: key,
      builder: (BuildContext context, BoxConstraints constraints) {
        double progress = 1.0;
        double height = constraints.maxHeight;
        final double collapsedHeight = MediaQuery.of(context).padding.top + 35.0;
        final double expandedAppBarHeight = 75.0;

        if (height > collapsedHeight) {
          final double maxHeight = expandedAppBarHeight + MediaQuery.of(context).padding.top;
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
                bottom: 16.0, // Matches CEAppBar
                left: 16.0,
                right: 16.0,
                child: Opacity(
                  opacity: largeTitleOpacity,
                  child: Row(
                    children: [
                      // Back button
                      IconButton(
                        icon: Icon(Icons.arrow_back_ios, size: 24, color: theme.colorScheme.onSurface),
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
                        icon: Icon(Icons.search, size: 24, color: theme.colorScheme.onSurface),
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
                          "Games",
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Flexible(child: SizedBox.shrink(), fit: FlexFit.tight),
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

  // New method to build the flexible space for search mode
  Widget _buildSearchFlexibleSpace(BuildContext context, ThemeData theme, {Key? key}) {
    return LayoutBuilder(
      key: key,
      builder: (BuildContext context, BoxConstraints constraints) {
        double progress = 1.0;
        double height = constraints.maxHeight;
        final double collapsedHeight = MediaQuery.of(context).padding.top + 35.0;
        final double expandedAppBarHeight = 75.0;

        if (height > collapsedHeight) {
          final double maxHeight = expandedAppBarHeight + MediaQuery.of(context).padding.top;
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
                bottom: 17.0, // Matches CEAppBar
                left: 16.0,
                right: 16.0,

                child: Opacity(
                  opacity: expandedOpacity,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_ios, size: 24, color: theme.colorScheme.onSurface),
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
                            hintText: "Search games, teams, sports...",
                            border: InputBorder.none,
                            hintStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6)),
                            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 0),
                          ),
                          style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 16),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, size: 24, color: theme.colorScheme.onSurface),
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
                          _searchController.text.isEmpty ? "Search" : ' "${_searchController.text}" in games',
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Flexible(child: SizedBox.shrink(), fit: FlexFit.tight),
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
            title: null, // Title is handled by flexibleSpace
            // Remove actions - now handled in the flexibleSpace
            flexibleSpace: AnimatedSwitcher(
              duration: _animationDuration,
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child:
                  _isSearching
                      ? _buildSearchFlexibleSpace(context, theme, key: const ValueKey('search_flexible_space'))
                      : _buildNormalFlexibleSpace(context, theme, key: const ValueKey('normal_flexible_space')),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Wrap(
                spacing: 4.0, // Horizontal spacing between chips
                runSpacing: 8.0, // Vertical spacing between rows of chips (increased from 0.0)
                children: [
                  ..._seasonOptions.map((label) => _buildChip(label, _selectedSeasonChips)).toList(),
                  ..._statusOptions.map((label) => _buildChip(label, _selectedStatusChips)).toList(),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver:
                _filteredGames.isEmpty
                    ? SliverFillRemaining(
                      child: Center(
                        child: Text(
                          _searchController.text.isNotEmpty ||
                                  _selectedSeasonChips.isNotEmpty ||
                                  _selectedStatusChips.isNotEmpty
                              ? "No games match your criteria."
                              : "Search or select filters to see games.",
                          style: TextStyle(fontSize: 16, color: theme.colorScheme.onSurface.withOpacity(0.6)),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                    : SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16.0,
                        mainAxisSpacing: 16.0,
                        mainAxisExtent: 160.0,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => GameWidget(game: _filteredGames[index]),
                        childCount: _filteredGames.length,
                      ),
                    ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: MediaQuery.of(context).padding.bottom + 24)),
        ],
      ),
    );
  }
}
