package com.roundcaddy.android

import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material.icons.filled.Dashboard
import androidx.compose.material.icons.filled.GolfCourse
import androidx.compose.material.icons.filled.List
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Place
import androidx.compose.material3.BottomAppBar
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import androidx.navigation.NavType
import com.roundcaddy.android.data.AppContainer
import com.roundcaddy.android.data.LocalAppContainer
import com.roundcaddy.android.round.LocalRoundSession
import com.roundcaddy.android.round.RoundSessionViewModel
import com.roundcaddy.android.ui.screens.AnalyticsScreen
import com.roundcaddy.android.ui.screens.ClubDistancesScreen
import com.roundcaddy.android.ui.screens.CoachingInsightsScreen
import com.roundcaddy.android.ui.screens.ContributeCourseScreen
import com.roundcaddy.android.ui.screens.CourseConfirmationScreen
import com.roundcaddy.android.ui.screens.CoursesScreen
import com.roundcaddy.android.ui.screens.CourseDetailScreen
import com.roundcaddy.android.ui.screens.DashboardScreen
import com.roundcaddy.android.ui.screens.DiscussionsScreen
import com.roundcaddy.android.ui.screens.HoleEntryScreen
import com.roundcaddy.android.ui.screens.LiveRoundScreen
import com.roundcaddy.android.ui.screens.LoginScreen
import com.roundcaddy.android.ui.screens.NewRoundScreen
import com.roundcaddy.android.ui.screens.NotificationsScreen
import com.roundcaddy.android.ui.screens.ProfileScreen
import com.roundcaddy.android.ui.screens.RoundsScreen
import com.roundcaddy.android.ui.screens.RoundDetailScreen
import com.roundcaddy.android.ui.screens.SavedHoleEditScreen
import com.roundcaddy.android.ui.screens.SavedShotEditScreen
import com.roundcaddy.android.ui.screens.ScorecardScreen
import com.roundcaddy.android.ui.screens.SwingAnalyticsScreen

private data class BottomNavItem(
    val route: String,
    val label: String,
    val icon: androidx.compose.ui.graphics.vector.ImageVector
)

@Composable
fun RoundCaddyApp() {
    val context = LocalContext.current
    val container = remember { AppContainer(context.applicationContext) }
    val roundSession = remember { RoundSessionViewModel() }
    val navController = rememberNavController()
    val backStack = navController.currentBackStackEntryAsState()
    val currentRoute = backStack.value?.destination?.route

    val bottomItems = listOf(
        BottomNavItem("dashboard", "Dashboard", Icons.Filled.Dashboard),
        BottomNavItem("rounds", "Rounds", Icons.Filled.List),
        BottomNavItem("live_round", "Live", Icons.Filled.GolfCourse),
        BottomNavItem("analytics", "Analytics", Icons.Filled.BarChart),
        BottomNavItem("courses", "Courses", Icons.Filled.Place),
        BottomNavItem("profile", "Profile", Icons.Filled.Person)
    )

    CompositionLocalProvider(
        LocalAppContainer provides container,
        LocalRoundSession provides roundSession
    ) {
        Scaffold(
            bottomBar = {
                if (bottomItems.any { it.route == currentRoute }) {
                    BottomAppBar {
                        bottomItems.forEach { item ->
                            NavigationBarItem(
                                selected = currentRoute == item.route,
                                onClick = {
                                    navController.navigate(item.route) {
                                        popUpTo(navController.graph.findStartDestination().id) {
                                            saveState = true
                                        }
                                        launchSingleTop = true
                                        restoreState = true
                                    }
                                },
                                icon = { Icon(item.icon, contentDescription = item.label) },
                                label = { Text(item.label) }
                            )
                        }
                    }
                }
            }
        ) { padding ->
            NavHost(
                navController = navController,
                startDestination = "login",
                modifier = Modifier.padding(padding)
            ) {
                composable("login") {
                    LoginScreen(
                        onLoginSuccess = {
                            navController.navigate("dashboard") {
                                popUpTo("login") { inclusive = true }
                            }
                        }
                    )
                }
                composable("dashboard") { DashboardScreen() }
                composable("rounds") {
                    RoundsScreen(
                        onNewRound = { navController.navigate("new_round") },
                        onOpenRound = { roundId -> navController.navigate("round_detail/$roundId") }
                    )
                }
                composable("live_round") { LiveRoundScreen(onEndRound = { navController.navigate("scorecard") }) }
                composable("analytics") { AnalyticsScreen() }
                composable("courses") {
                    CoursesScreen(onOpenCourse = { courseId ->
                        navController.navigate("course_detail/$courseId")
                    })
                }
                composable("profile") {
                    ProfileScreen(
                        onNavigateNotifications = { navController.navigate("notifications") },
                        onNavigateDiscussions = { navController.navigate("discussions?courseId=") },
                        onNavigateContribute = { navController.navigate("contribute_course") },
                        onNavigateConfirm = { navController.navigate("confirm_course") },
                        onNavigateClubDistances = { navController.navigate("club_distances") },
                        onNavigateCoaching = { navController.navigate("coaching") },
                        onNavigateSwingAnalytics = { navController.navigate("swing_analytics") }
                    )
                }
                composable("notifications") { NotificationsScreen() }
                composable(
                    route = "discussions?courseId={courseId}",
                    arguments = listOf(navArgument("courseId") { type = NavType.StringType; defaultValue = "" })
                ) { entry ->
                    val courseId = entry.arguments?.getString("courseId").orEmpty()
                    DiscussionsScreen(initialCourseId = courseId.ifBlank { null })
                }
                composable("contribute_course") { ContributeCourseScreen() }
                composable("confirm_course") { CourseConfirmationScreen() }
                composable("club_distances") { ClubDistancesScreen() }
                composable("coaching") { CoachingInsightsScreen() }
                composable("swing_analytics") { SwingAnalyticsScreen() }
                composable("scorecard") {
                    ScorecardScreen(onSelectHole = { hole ->
                        navController.navigate("hole_entry/$hole")
                    })
                }
                composable("new_round") {
                    NewRoundScreen(
                        onSaved = { navController.popBackStack() },
                        onCancel = { navController.popBackStack() }
                    )
                }
                composable(
                    route = "hole_entry/{holeNumber}",
                    arguments = listOf(navArgument("holeNumber") { type = NavType.IntType })
                ) { entry ->
                    val holeNumber = entry.arguments?.getInt("holeNumber") ?: 1
                    HoleEntryScreen(holeNumber = holeNumber) { navController.popBackStack() }
                }
                composable(
                    route = "course_detail/{courseId}",
                    arguments = listOf(navArgument("courseId") { type = NavType.StringType })
                ) { entry ->
                    val courseId = entry.arguments?.getString("courseId") ?: ""
                    CourseDetailScreen(
                        courseId = courseId,
                        onStartRound = { navController.navigate("live_round") },
                        onOpenDiscussions = { navController.navigate("discussions?courseId=$courseId") },
                        onConfirmCourse = { navController.navigate("confirm_course") }
                    )
                }
                composable(
                    route = "round_detail/{roundId}",
                    arguments = listOf(navArgument("roundId") { type = NavType.StringType })
                ) { entry ->
                    val roundId = entry.arguments?.getString("roundId") ?: ""
                    RoundDetailScreen(
                        roundId = roundId,
                        onResumeRound = { navController.navigate("live_round") },
                        onEditHole = { hole -> navController.navigate("round_hole_edit/$roundId/$hole") },
                        onEditShot = { shotId -> navController.navigate("shot_edit/$shotId") }
                    )
                }
                composable(
                    route = "round_hole_edit/{roundId}/{holeNumber}",
                    arguments = listOf(
                        navArgument("roundId") { type = NavType.StringType },
                        navArgument("holeNumber") { type = NavType.IntType }
                    )
                ) { entry ->
                    val roundId = entry.arguments?.getString("roundId") ?: ""
                    val holeNumber = entry.arguments?.getInt("holeNumber") ?: 1
                    SavedHoleEditScreen(roundId = roundId, holeNumber = holeNumber) {
                        navController.popBackStack()
                    }
                }
                composable(
                    route = "shot_edit/{shotId}",
                    arguments = listOf(navArgument("shotId") { type = NavType.StringType })
                ) { entry ->
                    val shotId = entry.arguments?.getString("shotId") ?: ""
                    SavedShotEditScreen(shotId = shotId) { navController.popBackStack() }
                }
            }
        }
    }
}
