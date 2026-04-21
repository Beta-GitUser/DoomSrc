version "4.10"

// Be warned, ye fool: This place is Hell. Once ye step in, God help you.

class DoomSrcPlayer : DoomPlayer
{
    Vector3 Vel;
    bool bOnGround;

    double MaxSpeed;
    double Accel;
    double AirAccel;
    double Friction;
    double Gravity;
    double JumpVel;

    Default
    {
        Player.DisplayName "DoomSrc Test Subject";

        Player.ForwardMove 0,0;
        Player.SideMove 0,0;
        Player.JumpZ 0;

        Speed 0;

        +NOGRAVITY
    }

    override void PostBeginPlay()
    {
        Super.PostBeginPlay();

        MaxSpeed = 8.0;
        Accel = 10.0;
        AirAccel = 0.1;
        Friction = 4.0;
        Gravity = 0.45;
        JumpVel = 6.4;

        Vel = (0,0,0);
    }

    override void PlayerThink()
    {
        Super.PlayerThink(); // i'm not reinventing weapons and camera

        UpdateGround();
        HandleJump();

        Vector3 wishvel = GetWishVel();
        Accelerate(wishvel);

        if (bOnGround)
        {
            ApplyFriction();
        }
    }

    override void Tick()
    {
        Super.Tick();

        ApplyGravity();
        MoveGSrc();

        // remaking positioning of the cam though (bobbing tbd)
        double targetZ = Pos.Z + ViewHeight;
        player.viewz += (targetZ - player.viewz) * 0.95;
    }

    // INPUT TO WISHVEL
    Vector3 GetWishVel()
    {
        double forward = player.cmd.forwardmove;
        double side = -player.cmd.sidemove;

        // use of in-house stuff cause i'm not a genius
        Vector2 fwd2 = AngleToVector(angle);
        
        Vector3 fwd;
        fwd.X = fwd2.X;
        fwd.Y = fwd2.Y;
        fwd.Z = 0; 

        // Build right vector (perpendicular)
        Vector3 right;
        right.X = fwd.Y;
        right.Y = fwd.X;
        right.Z = 0;

        Vector3 wishdir;
        wishdir.X = fwd.X * forward - right.X * side;
        wishdir.Y = fwd.Y * forward + right.Y * side;
        wishdir.Z = 0;

        double len = sqrt(wishdir.X * wishdir.X + wishdir.Y * wishdir.Y);

        if (len > 0)
        {
            wishdir.X /= len;
            wishdir.Y /= len;
        }

        Vector3 result;
        result.X = wishdir.X * MaxSpeed;
        result.Y = wishdir.Y * MaxSpeed;
        result.Z = 0;

        return result;
    }

    // ACCELERATION
    void Accelerate(Vector3 wishvel)
    {
        double wishspeed = sqrt(wishvel.X*wishvel.X + wishvel.Y*wishvel.Y);
        if (wishspeed <= 0) return;

        Vector3 wishdir;
        wishdir.X = wishvel.X / wishspeed;
        wishdir.Y = wishvel.Y / wishspeed;
        wishdir.Z = 0;

        double currentspeed = Vel.X * wishdir.X + Vel.Y * wishdir.Y;
        double addspeed = wishspeed - currentspeed;

        if (addspeed <= 0) return;

        double accel = bOnGround ? Accel : AirAccel;

        double accelspeed = accel * wishspeed * 0.2;
        if (accelspeed > addspeed)
            accelspeed = addspeed;

        Vel.X += wishdir.X * accelspeed;
        Vel.Y += wishdir.Y * accelspeed;
    }

    // FRICTION
    void ApplyFriction()
    {
        double speed = sqrt(Vel.X*Vel.X + Vel.Y*Vel.Y);
    
        if (speed < 0.1)
            return;
    
        double control = speed < 2.0 ? 2.0 : speed; // i suggest not changing this at all
        double drop = control * Friction * 0.05;
    
        double newspeed = speed - drop;
        if (newspeed < 0)
            newspeed = 0;
    
        if (speed > 0)
        {
            Vel.X *= newspeed / speed;
            Vel.Y *= newspeed / speed;
        }
    }

    // GRAVITY
    void ApplyGravity()
    {
        if (!bOnGround)
        {
            Vel.Z -= Gravity;
        }
    }

    // GROUND CHECK
    void UpdateGround()
    {
        double floorZ = GetZAt();

        if (Pos.Z <= floorZ + 1.0)
        {
            bOnGround = true;

            if (Vel.Z < 0)
                Vel.Z = 0;

            Vector3 newPos = Pos;
            newPos.Z += Vel.Z;
            
            // Only apply if valid
            if (TryMove(newPos.XY, true))
            {
                SetOrigin(newPos, true);
            }
            else
            {
                // Hit ceiling/floor or stuck
                Vel.Z = 0;
            }
        }
        else
        {
            bOnGround = false;
        }
        Unstuck();
    }

    // JUMP
    void HandleJump()
    {
        if (player.cmd.buttons & BT_JUMP)
        {
            if (bOnGround)
            {
                Vel.Z = JumpVel;
                bOnGround = false;
            }
        }
    }

    // MOVEMENT (slope fix tbd)
    void MoveGSrc()
    {
        Vector2 move;
        move.X = Vel.X;
        move.Y = Vel.Y;

        if (!TryMove(Pos.XY + move, true))
        {
            // X attempt
            Vector2 moveX;
            moveX.X = Vel.X;
            moveX.Y = 0;

            if (TryMove(Pos.XY + moveX, true))
            {
                Vel.Y = 0;
            }
            else
            {
                // Y attempt
                Vector2 moveY;
                moveY.X = 0;
                moveY.Y = Vel.Y;

                if (TryMove(Pos.XY + moveY, true))
                {
                    Vel.X = 0;
                }
                else
                {
                    Vel.X = 0;
                    Vel.Y = 0;
                }
            }
        }

        SetOrigin((Pos.X, Pos.Y, Pos.Z + Vel.Z), true);
    }
    void Unstuck() // as of writing this, gravity code fucking ignores existance of actor's radius i can't get it to work fuck
    {
        if (TryMove(Pos.XY, true))
        {
            return;
        }
    
        Vector2 offsets[8] = {
            (1,0), (-1,0), (0,1), (0,-1),
            (1,1), (-1,1), (1,-1), (-1,-1)
        };
    
        for (int i = 0; i < 8; i++)
        {
            Vector2 testPos = Pos.XY + offsets[i];
    
            if (TryMove(testPos, true))
            {
                return;
            }
        }
    }
}