package main

import "core:fmt"
import "core:net"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import rl "vendor:raylib"

GameState :: struct {
    window_size: rl.Vector2,
    paddle: rl.Rectangle,
    player_score: int,
    ai_paddle: rl.Rectangle,
    ai_score: int,
    ai_target_y: f32,
    ai_reaction_delay: f32,
    ai_reaction_timer: f32,
    paddle_speed: f32,
    ball: rl.Rectangle,
    ball_speed: f32,
    ball_dir: rl.Vector2,
    boost_timer: f32,
}

reset :: proc (gs: ^GameState) {
    angle := rand.float32_range(-45, 46)

    if rand.int_max(100) % 2 == 0 {
        angle += 180
    }

    r := math.to_radians(angle)

    gs.ball_dir.x = math.cos(r)
    gs.ball_dir.y = math.sin(r)

    gs.ball.x = gs.window_size.x / 2 - gs.ball.width / 2
    gs.ball.y = gs.window_size.y / 2 - gs.ball.width / 2 

    paddle_margin: f32 = 50

    gs.paddle.x = gs.window_size.x - (gs.paddle.width + paddle_margin) 
    gs.paddle.y = gs.window_size.y / 2 - gs.paddle.height / 2 

    gs.ai_paddle.x = paddle_margin
    gs.ai_paddle.y = gs.window_size.y / 2 - gs.ai_paddle.height / 2
}

ball_calculate_direction :: proc(ball: rl.Rectangle, paddle: rl.Rectangle) -> (rl.Vector2, bool) {
    if rl.CheckCollisionRecs(ball, paddle) {
        ball_center := rl.Vector2{ball.x + ball.width / 2, ball.y + ball.height / 2}
        paddle_center := rl.Vector2{paddle.x + paddle.width / 2, paddle.y + paddle.height / 2}
        return linalg.normalize0(ball_center - paddle_center), true
    }

    return {}, false
}

main :: proc() {
    gs := GameState{
        window_size = {1280, 720},
        paddle = {width = 30, height = 80},
        ai_paddle = {width = 30, height = 80},
        ai_reaction_delay = 0.1,
        paddle_speed = 10,
        ball = {width = 25, height = 25},
        ball_speed = 10,
    }

    reset(&gs)

    rl.InitWindow(i32(gs.window_size.x), i32(gs.window_size.y), "Pong")
    rl.SetTargetFPS(45)

    rl.InitAudioDevice()
    defer rl.CloseAudioDevice()

    sfx_hit := rl.LoadSound("hit.wav")
    sfx_win := rl.LoadSound("win.wav")
    sfx_lose := rl.LoadSound("lose.wav")
    
    for !rl.WindowShouldClose() {
        if rl.IsKeyDown(.UP) {
            gs.paddle.y -= gs.paddle_speed
        }

        if rl.IsKeyDown(.DOWN) {
            gs.paddle.y += gs.paddle_speed
        }

        gs.paddle.y = linalg.clamp(gs.paddle.y, 0, gs.window_size.y - gs.paddle.height)

        gs.ai_reaction_timer += rl.GetFrameTime()

        if gs.ai_reaction_timer >= gs.ai_reaction_delay {
            gs.ai_reaction_timer = 0

            ball_mid := gs.ball.y + gs.ball.height / 2

            // track the ball heading towards the paddle or reset to the middle
            if gs.ball_dir.x < 0 {
                gs.ai_target_y = ball_mid - gs.ai_paddle.height / 2
                // random inaccuracy
                gs.ai_target_y += rand.float32_range(-20, 20)
            } else {
                gs.ai_target_y = gs.window_size.y / 2 - gs.ai_paddle.height / 2
            }
        }

        ai_paddle_mid := gs.ai_paddle.y + gs.ai_paddle.height / 2
        target_diff := gs.ai_target_y - gs.ai_paddle.y 

        gs.ai_paddle.y += linalg.clamp(target_diff, -gs.paddle_speed, gs.paddle_speed) * 0.60
        gs.ai_paddle.y = linalg.clamp(gs.ai_paddle.y, 0, gs.window_size.y - gs.ai_paddle.height)

        next_ball_rect := gs.ball
        next_ball_rect.x += gs.ball_speed * gs.ball_dir.x
        next_ball_rect.y += gs.ball_speed * gs.ball_dir.y

        if next_ball_rect.x >= gs.window_size.x - gs.ball.width {
            gs.ai_score += 1
            rl.PlaySound(sfx_lose)
            reset(&gs)
        }

        if next_ball_rect.x < 0 {
            gs.player_score += 1
            rl.PlaySound(sfx_win)
            reset(&gs)
        }

        if next_ball_rect.y >= 720 - gs.ball.height || next_ball_rect.y <= 0 {
            gs.ball_dir.y *= -1
        }

        last_ball_dir := gs.ball_dir

        gs.ball_dir = ball_calculate_direction(next_ball_rect, gs.paddle) or_else gs.ball_dir
        gs.ball_dir = ball_calculate_direction(next_ball_rect, gs.ai_paddle) or_else gs.ball_dir

        if last_ball_dir != gs.ball_dir {
            rl.PlaySound(sfx_hit)
        }

        gs.ball.y += gs.ball_speed * gs.ball_dir.y
        gs.ball.x += gs.ball_speed * gs.ball_dir.x

        rl.BeginDrawing()

        rl.ClearBackground(rl.BLACK)
         
        rl.DrawRectangleRec(gs.paddle, rl.WHITE)

        rl.DrawRectangleRec(gs.ai_paddle, rl.WHITE)

        rl.DrawRectangleRec(gs.ball, rl.RED)

        rl.DrawText(fmt.ctprintf("{}", gs.ai_score), 12, 12, 32, rl.WHITE)

        rl.DrawText(fmt.ctprintf("{}", gs.player_score), i32(gs.window_size.x) - 28, 12, 32, rl.WHITE)

        rl.EndDrawing()

        // prevent ctprintf c string memory leak
        free_all(context.temp_allocator)
    }
}