package com.recallthat.App

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.recallthat.Views.MainNavHost

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val env = (application as RecallThatApplication).appEnvironment
        setContent {
            RecallThatTheme {
                MainNavHost(env = env)
            }
        }
    }
}
