package com.recallthat.Views

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import com.recallthat.App.AppEnvironment
import com.recallthat.Models.Memory
import java.util.UUID

@Composable
fun MainNavHost(env: AppEnvironment) {
    val navController = rememberNavController()
    var selectedTab by rememberSaveable { mutableIntStateOf(0) }

    Scaffold(
        bottomBar = {
            NavigationBar {
                NavigationBarItem(
                    selected = selectedTab == 0,
                    onClick = {
                        selectedTab = 0
                        navController.navigate("home") {
                            popUpTo(navController.graph.findStartDestination().id) { saveState = true }
                            launchSingleTop = true
                            restoreState = true
                        }
                    },
                    icon = { Icon(Icons.Default.Home, contentDescription = "Home") },
                    label = { Text("Home") }
                )
                NavigationBarItem(
                    selected = selectedTab == 1,
                    onClick = {
                        selectedTab = 1
                        navController.navigate("search") {
                            popUpTo(navController.graph.findStartDestination().id) { saveState = true }
                            launchSingleTop = true
                            restoreState = true
                        }
                    },
                    icon = { Icon(Icons.Default.Search, contentDescription = "Search") },
                    label = { Text("Search") }
                )
            }
        }
    ) { _ ->
        NavHost(navController = navController, startDestination = "home") {
            composable("home") {
                HomeScreen(env = env, onMemoryClick = { id ->
                    navController.navigate("detail/$id")
                })
            }
            composable("search") {
                SearchScreen(env = env, onMemoryClick = { id ->
                    navController.navigate("detail/$id")
                })
            }
            composable("detail/{memoryId}") { backStack ->
                val id = backStack.arguments?.getString("memoryId") ?: return@composable
                var memory by remember { mutableStateOf<Memory?>(null) }
                LaunchedEffect(id) {
                    memory = env.memoryRepository.fetch(UUID.fromString(id))
                }
                memory?.let { m ->
                    MemoryDetailScreen(
                        memory = m,
                        env = env,
                        onBack = { navController.popBackStack() }
                    )
                }
            }
        }
    }
}
