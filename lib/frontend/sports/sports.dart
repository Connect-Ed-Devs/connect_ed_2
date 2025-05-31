import 'package:carousel_slider/carousel_slider.dart';
import 'package:cached_network_image/cached_network_image.dart'; // Add this import at the top of the file
import 'package:connect_ed_2/classes/athlete_article.dart';
import 'package:connect_ed_2/classes/game.dart';
import 'package:connect_ed_2/frontend/setup/app_bar.dart';
import 'package:connect_ed_2/frontend/setup/opacity_button.dart';
import 'package:connect_ed_2/frontend/sports/game_widgets.dart';
import 'package:connect_ed_2/frontend/sports/otw.dart';
import 'package:connect_ed_2/frontend/sports/team_widget.dart';
import 'package:connect_ed_2/classes/team.dart';
import 'package:connect_ed_2/frontend/sports/game_search.dart';
import 'package:connect_ed_2/frontend/sports/teams_search.dart';
import 'package:flutter/material.dart';
import 'package:connect_ed_2/requests/athlete_cache_manager.dart';
import 'package:connect_ed_2/requests/games_cache_manager.dart'; // Add games cache manager
import 'package:connect_ed_2/classes/standings_list.dart';
import 'package:connect_ed_2/requests/standings_cache_manager.dart';

class SportsPage extends StatefulWidget {
  const SportsPage({super.key});

  @override
  State<SportsPage> createState() => _SportsPageState();
}

class _SportsPageState extends State<SportsPage> {
  int _currentIndex = 0;

  // Add athlete articles data
  List<AthleteArticle> _athleteArticles = [];
  bool _isLoadingArticles = true;
  bool _hasArticleLoadError = false;
  String? _articleErrorMessage;

  // Add game data variables
  Map<String, Game> _allGames = {};
  List<Game> _recentGames = [];
  List<Game> _upcomingGames = [];
  bool _isLoadingGames = true;
  bool _hasGamesLoadError = false;
  String? _gamesErrorMessage;

  // Add team data variables
  Map<String, StandingsList>? _standingsData;
  List<Team> _applebyTeams = [];
  bool _isLoadingTeams = true;
  bool _hasTeamsLoadError = false;
  String? _teamsErrorMessage;

  @override
  void initState() {
    super.initState();
    _loadAthleteArticles();
    _loadGamesData();
    _loadTeamsData();
  }

  // Load athlete articles data
  Future<void> _loadAthleteArticles() async {
    setState(() {
      _isLoadingArticles = true;
      _hasArticleLoadError = false;
    });

    try {
      // Try to get cached data first
      Map<String, List<AthleteArticle>>? cachedData;
      try {
        cachedData = athleteManager.getCachedData();
      } catch (e) {
        print('Error accessing cached athlete articles: $e');
      }

      // If no cached data, fetch fresh data
      cachedData ??= await athleteManager.fetchData();

      setState(() {
        _athleteArticles = cachedData?['articles'] ?? [];
        _isLoadingArticles = false;
      });
    } catch (error) {
      setState(() {
        _isLoadingArticles = false;
        _hasArticleLoadError = true;
        _articleErrorMessage = error.toString();
      });
      print('Error loading athlete articles: $error');
    }
  }

  // Load games data
  Future<void> _loadGamesData() async {
    setState(() {
      _isLoadingGames = true;
      _hasGamesLoadError = false;
    });

    try {
      // Try to get cached data first
      Map<String, Game>? cachedGames;
      try {
        cachedGames = gamesManager.getCachedData();
      } catch (e) {
        print('Error accessing cached games: $e');
      }

      // If no cached data, fetch fresh data
      cachedGames ??= await gamesManager.fetchData();

      // Process the games data
      setState(() {
        _allGames = cachedGames ?? {};
        _processGamesData();
        _isLoadingGames = false;
      });
    } catch (error) {
      setState(() {
        _isLoadingGames = false;
        _hasGamesLoadError = true;
        _gamesErrorMessage = error.toString();
      });
      print('Error loading games data: $error');
    }
  }

  // Load teams data
  Future<void> _loadTeamsData() async {
    setState(() {
      _isLoadingTeams = true;
      _hasTeamsLoadError = false;
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
        _extractApplebyTeams();
        _isLoadingTeams = false;
      });
    } catch (error) {
      setState(() {
        _isLoadingTeams = false;
        _hasTeamsLoadError = true;
        _teamsErrorMessage = error.toString();
      });
      print('Error loading teams data: $error');
    }
  }

  // Extract Appleby teams from standings data
  void _extractApplebyTeams() {
    _applebyTeams = [];

    if (_standingsData != null) {
      _standingsData!.forEach((leagueCode, standingsList) {
        // Add team if it exists
        // Use the sport name instead of school name
        final sportName = standingsList.sportsName;
        Team team = standingsList.applebyTeam;

        // Create new team with sport name instead of "Appleby College"
        _applebyTeams.add(
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
      _applebyTeams.sort((a, b) => a.rank.compareTo(b.rank));
    }
  }

  // Process games data for recent and upcoming games
  void _processGamesData() {
    final now = DateTime.now();
    List<Game> allGamesList = _allGames.values.toList();

    // Sort games by date
    allGamesList.sort((a, b) => a.date.compareTo(b.date));

    // Recent games - games in the past with scores
    List<Game> playedGames =
        allGamesList
            .where(
              (game) =>
                  game.date.isBefore(now) &&
                  game.homeScore != '-' &&
                  game.awayScore != '-',
            )
            .toList();

    // Sort played games by date descending (most recent first)
    playedGames.sort((a, b) => b.date.compareTo(a.date));

    // Upcoming games - games in the future or with no scores
    List<Game> upcoming =
        allGamesList
            .where(
              (game) =>
                  game.date.isAfter(now) ||
                  (game.homeScore == '-' && game.awayScore == '-'),
            )
            .toList();

    // Sort upcoming games by date ascending (closest first)
    upcoming.sort((a, b) => a.date.compareTo(b.date));

    // Take the 5 most recent games and 5 closest upcoming games
    _recentGames = playedGames.take(5).toList();
    _upcomingGames = upcoming.take(5).toList();
  }

  @override
  Widget build(BuildContext context) {
    // Filter for "Athlete of the Week" and "Team of the Week" articles
    final otw = _athleteArticles.toList();

    // Use actual count or fallback to at least 1 for the carousel
    final int otwItemCount = otw.isEmpty ? 1 : otw.length;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          CEAppBar(title: 'Sports'),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _isLoadingArticles
                    ? Container(
                      height: 256,
                      margin: EdgeInsets.symmetric(horizontal: 16),
                      child: _ArticleSkeletonLoader(),
                    )
                    : _hasArticleLoadError
                    ? Container(
                      height: 256,
                      margin: EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        // Change from color fill to border
                        border: Border.all(
                          color: Theme.of(context).colorScheme.error,
                          width: 2.0,
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 48,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Could not load featured athletes',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                // Update text color for better contrast on white background
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                            SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: _loadAthleteArticles,
                              icon: Icon(Icons.refresh, size: 16),
                              label: Text('Retry'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    Theme.of(context).colorScheme.error,
                                foregroundColor:
                                    Theme.of(context).colorScheme.onError,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    : otw.isEmpty
                    ? Container(
                      height: 256,
                      margin: EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color:
                            Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                      ),
                      child: Center(
                        child: Text(
                          'No featured athletes this week',
                          style: TextStyle(
                            fontSize: 16,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                    : CarouselSlider.builder(
                      itemCount: otw.length,
                      itemBuilder: (
                        BuildContext context,
                        int itemIndex,
                        int pageViewIndex,
                      ) {
                        return OTWWidget(
                          uniqueId: otw[itemIndex].id ?? itemIndex.toString(),
                          article: otw[itemIndex],
                        );
                      },
                      options: CarouselOptions(
                        viewportFraction: 1.0,
                        enableInfiniteScroll: otw.length > 1,
                        height: 256,
                        autoPlay: otw.length > 1,
                        autoPlayInterval: Duration(seconds: 5),
                        onPageChanged: (index, reason) {
                          setState(() {
                            _currentIndex = index;
                          });
                        },
                      ),
                    ),
                const SizedBox(height: 12),
                // Only show indicators if there are multiple items
                otw.length > 1
                    ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(otw.length, (index) {
                        return Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                _currentIndex == index
                                    ? Theme.of(context).colorScheme.onSurface
                                    : Theme.of(context).colorScheme.onSurface
                                        .withValues(alpha: 127),
                          ),
                        );
                      }),
                    )
                    : SizedBox.shrink(),
              ],
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: 32)),
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
                  ),
                  OpacityTextButton(
                    text: 'View More',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) =>
                                  const GameSearchPage(initialFilter: 'played'),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 190,
              child:
                  _isLoadingGames
                      ? Center(child: CircularProgressIndicator())
                      : _hasGamesLoadError
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Could not load games',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                            TextButton(
                              onPressed: _loadGamesData,
                              child: Text('Retry'),
                            ),
                          ],
                        ),
                      )
                      : _recentGames.isEmpty
                      ? Center(child: Text('No recent games found'))
                      : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _recentGames.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(
                              right: 16,
                              top: 8,
                              bottom: 8,
                            ),
                            child: GameWidget(game: _recentGames[index]),
                          );
                        },
                      ),
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: 32)),
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Upcoming',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
                  ),
                  OpacityTextButton(
                    text: 'View More',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => const GameSearchPage(
                                initialFilter: 'upcoming',
                              ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 190,
              child:
                  _isLoadingGames
                      ? Center(child: CircularProgressIndicator())
                      : _hasGamesLoadError
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Could not load games',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                            TextButton(
                              onPressed: _loadGamesData,
                              child: Text('Retry'),
                            ),
                          ],
                        ),
                      )
                      : _upcomingGames.isEmpty
                      ? Center(child: Text('No upcoming games found'))
                      : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _upcomingGames.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(
                              right: 16,
                              top: 8,
                              bottom: 8,
                            ),
                            child: GameWidget(game: _upcomingGames[index]),
                          );
                        },
                      ),
            ),
          ),

          SliverToBoxAdapter(child: SizedBox(height: 32)),
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Teams',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
                  ),
                  OpacityTextButton(
                    text: 'View More',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TeamsSearchPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 190,
              child:
                  _isLoadingTeams
                      ? Center(child: CircularProgressIndicator())
                      : _hasTeamsLoadError
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Could not load teams',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                            TextButton(
                              onPressed: _loadTeamsData,
                              child: Text('Retry'),
                            ),
                          ],
                        ),
                      )
                      : _applebyTeams.isEmpty
                      ? Center(child: Text('No teams found'))
                      : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount:
                            _applebyTeams.length > 5
                                ? 5
                                : _applebyTeams.length, // Show max 5 teams
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 16.0),
                            child: TeamWidget(team: _applebyTeams[index]),
                          );
                        },
                      ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(height: 64 + MediaQuery.of(context).padding.bottom),
          ),
        ],
      ),
    );
  }
}

class OTWWidget extends StatelessWidget {
  final String uniqueId;
  final AthleteArticle article;

  const OTWWidget({super.key, required this.uniqueId, required this.article});

  @override
  Widget build(BuildContext context) {
    // Construct unique tags
    final String bannerTag = 'banner-$uniqueId';
    final String athleteNameTag = 'athlete-name-$uniqueId';
    final String athleteTitleTag = 'athlete-title-$uniqueId';

    final String typeTitle =
        article.type == 'athlete' ? 'Athlete of The Week' : 'Team of The Week';

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder:
                (context) => OTWScreen(
                  bannerTag: bannerTag,
                  athleteNameTag: athleteNameTag,
                  athleteTitleTag: athleteTitleTag,
                  article: article,
                ),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16),
        height: 256,
        child: Stack(
          children: [
            Hero(
              tag: bannerTag,
              child: Stack(
                children: [
                  // Replace NetworkImage with CachedNetworkImage
                  ClipRRect(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                    child: CachedNetworkImage(
                      imageUrl: article.imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      placeholder:
                          (context, url) => Container(
                            color:
                                Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                            child: Center(child: CircularProgressIndicator()),
                          ),
                      errorWidget:
                          (context, url, error) => Container(
                            color:
                                Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                            child: Center(
                              child: Icon(
                                Icons.error_outline,
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                    ),
                  ),
                  // Gradient overlay - use the same borderRadius as the image
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter + Alignment(0, 0.375),
                        end: Alignment.topCenter + Alignment(0, 1.25),
                        colors: [
                          Colors.black.withValues(alpha: 190),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Text content with Hero animations
            Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Hero(
                        tag: athleteNameTag,
                        child: Material(
                          color: Colors.transparent,
                          child: Text(
                            article.name,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      Hero(
                        tag: athleteTitleTag,
                        child: Material(
                          color: Colors.transparent,
                          child: Text(
                            typeTitle,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Icon(Icons.arrow_forward_ios, color: Colors.white, size: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A skeleton loader for athlete articles that mimics the article preview shape
class _ArticleSkeletonLoader extends StatefulWidget {
  const _ArticleSkeletonLoader({super.key});

  @override
  State<_ArticleSkeletonLoader> createState() => _ArticleSkeletonLoaderState();
}

class _ArticleSkeletonLoaderState extends State<_ArticleSkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _opacityAnimation = Tween<double>(
      begin: 0.3,
      end: 0.6,
    ).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacityAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            // Replace gradient with a gray border
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 127),
              width: 1.0,
            ),
          ),
          child: Stack(
            children: [
              // Header text placeholder
              Positioned(
                top: 16,
                left: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title placeholder
                    Container(
                      width: 180,
                      height: 24,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: Theme.of(context).colorScheme.onSurface
                            .withValues(alpha: _opacityAnimation.value),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Subtitle placeholder
                    Container(
                      width: 120,
                      height: 12,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: Theme.of(context).colorScheme.onSurface
                            .withValues(alpha: _opacityAnimation.value),
                      ),
                    ),
                  ],
                ),
              ),

              // Arrow icon placeholder
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Theme.of(context).colorScheme.onSurface.withValues(
                      alpha: _opacityAnimation.value,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
